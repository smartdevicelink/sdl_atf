--- Module which is responsible for protocol level message handling and provides ProtocolHandler type
--
-- *Dependencies:* `json`, `protocol_handler.ford_protocol_constants`, `bit32`
--
-- *Globals:* `bit32`, ret
-- @module protocol_handler.protocol_handler
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local ProtocolHandler = {}
local json = require("json")
local constants = require('protocol_handler/ford_protocol_constants')
local mt = { __index = { } }

--- Type which represents protocol level message handling
-- @type ProtocolHandler

--- Construct instance of ProtocolHandler type
-- @treturn ProtocolHandler Constructed instance
function ProtocolHandler.ProtocolHandler()
  local ret =
  {
    buffer = "",
    frames = { }
  }
  setmetatable(ret, mt)
  return ret
end

--- Build byte representation of int32
-- @tparam userdata val Original int32 value
-- @treturn string Byte representation of int32
local function int32ToBytes(val)
  local res = string.char(
    bit32.rshift(bit32.band(val, 0xff000000), 24),
    bit32.rshift(bit32.band(val, 0xff0000), 16),
    bit32.rshift(bit32.band(val, 0xff00), 8),
    bit32.band(val, 0xff)
  )
  return res
end

--- Build int32 value from its byte representation
-- @tparam string val Byte representation of int32
-- @tparam number offset Offset
-- @treturn userdata Built int32 value
local function bytesToInt32(val, offset)
  local res = bit32.lshift(string.byte(val, offset), 24) +
  bit32.lshift(string.byte(val, offset + 1), 16) +
  bit32.lshift(string.byte(val, offset + 2), 8) +
  string.byte(val, offset + 3)
  return res
end

--- Build byte representation of RPC payload
-- @tparam number rpcType RPC type
-- @tparam number rpcFunctionId Function Id
-- @tparam number rpcCorrelationId RPC correlation ID
-- @tparam string payload Data
-- @treturn string Built byte representation of RPC payload
local function rpcPayload(rpcType, rpcFunctionId, rpcCorrelationId, payload)
  local res = string.char(
    bit32.lshift(rpcType, 4) + bit32.band(bit32.rshift(rpcFunctionId, 24), 0x0f),
    bit32.rshift(bit32.band(rpcFunctionId, 0xff0000), 16),
    bit32.rshift(bit32.band(rpcFunctionId, 0xff00), 8),
    bit32.band(rpcFunctionId, 0xff)) ..
  int32ToBytes(rpcCorrelationId) ..
  int32ToBytes(#payload) ..
  payload
  return res
end

--- Build byte representation of message header
-- @tparam number version Version number of the ford protocol
-- @tparam number encryption Encription flag
-- @tparam number frameType Frame type
-- @tparam number serviceType Service type
-- @tparam number frameInfo Frame info
-- @tparam number sessionId Session Id
-- @tparam string payload Data
-- @tparam number messageId Message Id
-- @treturn string Built byte representation of header
-- @see `Applink Protocol`
local function create_ford_header(version, encryption, frameType, serviceType, frameInfo, sessionId, payload, messageId)
  local res = string.char(
    bit32.bor(
      bit32.lshift(version, 4),
      (encryption and 0x08 or 0),
      bit32.band(frameType, 0x07)),
    serviceType,
    frameInfo,
    sessionId) ..
  (payload and int32ToBytes(#payload) or string.char(0, 0, 0, 0)) .. -- size
  int32ToBytes(messageId)
  return res
end

--- Parse binary message from SDL to table with json validation
-- @tparam string binary Message
-- @tparam boolean validateJson True if JSON validation is required
-- @treturn table Parsed message
function mt.__index:Parse(binary, validateJson)
  self.buffer = self.buffer .. binary
  local res = { }
  while #self.buffer >= 12 do
    local msg = {}
    local c1 = string.byte(self.buffer, 1)
    msg.size = bytesToInt32(self.buffer, 5)
    if #self.buffer < msg.size + 12 then break end
    msg.version = bit32.rshift(bit32.band(c1, 0xf0), 4)
    msg.frameType = bit32.band(c1, 0x07)
    msg.encryption = bit32.band(c1, 0x08) == 0x08
    msg.serviceType = string.byte(self.buffer, 2)
    msg.frameInfo = string.byte(self.buffer, 3)
    msg.sessionId = string.byte(self.buffer, 4)
    msg.messageId = bytesToInt32(self.buffer, 9)
    msg.binaryData = string.sub(self.buffer, 13, msg.size + 12)
    self.buffer = string.sub(self.buffer, msg.size + 13)
    if #msg.binaryData == 0 or msg.frameType == constants.FRAME_TYPE.CONTROL_FRAME then
      table.insert(res, msg)
    else
      if msg.frameType == constants.FRAME_TYPE.SINGLE_FRAME or
      (msg.frameType == constants.FRAME_TYPE.CONSECUTIVE_FRAME and msg.frameInfo == constants.FRAME_INFO.LAST_FRAME) then
        if msg.frameType == constants.FRAME_TYPE.CONSECUTIVE_FRAME then
          msg.binaryData = self.frames[msg.messageId] .. msg.binaryData
          self.frames[msg.messageId] = nil
        end
        if msg.serviceType == constants.SERVICE_TYPE.RPC or
        msg.serviceType == constants.SERVICE_TYPE.BULK_DATA then
          msg.rpcType = bit32.rshift(string.byte(msg.binaryData, 1), 4)
          msg.rpcFunctionId = bit32.band(bytesToInt32(msg.binaryData, 1), 0x0fffffff)
          msg.rpcCorrelationId = bytesToInt32(msg.binaryData, 5)
          msg.rpcJsonSize = bytesToInt32(msg.binaryData, 9)
          if msg.rpcJsonSize > 0 then
            if not validateJson then
              msg.payload = json.decode(string.sub(msg.binaryData, 13, msg.rpcJsonSize + 12))
            end
          end
          if msg.size > msg.rpcJsonSize + 12 then
            msg.binaryData = string.sub(msg.binaryData, msg.rpcJsonSize + 13)
          else
            msg.binaryData = ""
          end
        end
        table.insert(res, msg)
      elseif msg.frameType == constants.FRAME_TYPE.FIRST_FRAME then
        self.frames[msg.messageId] = ""
      elseif msg.frameType == constants.FRAME_TYPE.CONSECUTIVE_FRAME then
        self.frames[msg.messageId] = self.frames[msg.messageId] .. msg.binaryData
      end
    end
  end
  return res
end

--- Compose table with binary message and header for SDL
-- @tparam table message Table representation of message
-- @treturn table Table with binary message and header
function mt.__index:Compose(message)
  local kMax_protocol_payload_size = 1488
  local kFirstframe_frameType = 0x02
  local kFirstframe_frameInfo = 0
  local kFirstframe_dataSize = 0x08
  local kConsecutiveframe_frameType = 0x03
  local payload = nil
  local header = nil
  local is_multi_frame = false
  local res = {}
  local multiframe_payloads = {}

  if message.frameType ~= constants.FRAME_TYPE.CONTROL_FRAME and
    (message.serviceType == constants.SERVICE_TYPE.RPC or
      message.serviceType == constants.SERVICE_TYPE.BULK_DATA)
    and message.payload then
    payload = rpcPayload(message.rpcType,
      message.rpcFunctionId,
      message.rpcCorrelationId,
      message.payload)
  end

  if message.binaryData then
    if payload then
      payload = payload .. message.binaryData
    else payload = message.binaryData
    end
  end

  local payload_size
  if payload then payload_size = #payload end

  if payload and #payload > kMax_protocol_payload_size then
    is_multi_frame = true
    while #payload > 0 do
      local payload_part = string.sub(payload, 1, kMax_protocol_payload_size)
      payload = string.sub(payload, kMax_protocol_payload_size + 1)
      table.insert(multiframe_payloads, payload_part)
    end
  end

  if is_multi_frame then
    -- 1st frame
    local firstFrame_payload = int32ToBytes(payload_size) .. int32ToBytes(#multiframe_payloads)
    local frame = nil
    header = create_ford_header(message.version,
      message.encryption,
      kFirstframe_frameType,
      message.serviceType,
      kFirstframe_frameInfo,
      message.sessionId,
      firstFrame_payload,
      message.messageId)
    frame = header .. firstFrame_payload
    table.insert(res, frame)

    for frame_number = 1, #multiframe_payloads do
      local frame_info
      if frame_number == #multiframe_payloads then --last frame
        frame_info = 0
      else
        -- frame info range should be [1 - 255].
        -- frame info can't be 0, 0 mean last frame
        frame_info = ((frame_number - 1) % 255) + 1
      end
      header = create_ford_header(message.version, message.encryption, kConsecutiveframe_frameType, message.serviceType,
        frame_info, message.sessionId, multiframe_payloads[frame_number], message.messageId)
      frame = header .. multiframe_payloads[frame_number]
      table.insert(res, frame)
    end
  else
    header = create_ford_header(message.version, message.encryption, message.frameType, message.serviceType,
      message.frameInfo, message.sessionId, payload or "", message.messageId)
    if payload then
      table.insert(res, header .. payload)
    else
      table.insert(res, header)
    end
  end
  return res
end

return ProtocolHandler
