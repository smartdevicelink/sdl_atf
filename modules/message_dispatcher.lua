--- Module which provides low level handling of communications between ATF and SDL
--
-- It provides FileStorage, FileStream and MessageDispatcher types
--
-- *Dependencies:* `protocol_handler.protocol_handler`, `config`, `qt`
--
-- *Globals:* `timestamp`, `errmsg`, `config`, `qt`, `timers`, `atf_logger`
-- @module message_dispatcher
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

-- Communications MOB with SDL

local ph = require('protocol_handler/protocol_handler')
local constants = require('protocol_handler/ford_protocol_constants')

local MD = {
  mt = { __index = { } }
}
local fbuffer_mt = { __index = { } }
local fstream_mt = { __index = { } }

--- Type which provides file-buffer for communications ATF and SDL
-- @type FileStorage

--- Construct instance of FileStorage type
-- @tparam string filename File name which used as buffer
-- @treturn FileStorage Constructed instance
function MD.FileStorage(filename)
  local res = {}
  res.filename = filename
  res.protocol_handler = ph.ProtocolHandler()
  res.wfd = io.open(filename, "w")
  res.rfd = io.open(filename, "r")
  setmetatable(res, fbuffer_mt)
  return res
end

--- Suspend message in buffer
-- @tparam string msg Message
function fbuffer_mt.__index:KeepMessage(msg)
  self.keep = msg
end

--- Read and parse message from SDL to table
-- @treturn table Ford protocol frame
function fbuffer_mt.__index:GetMessage()
  if self.keep then
    local res = self.keep
    self.keep = nil
    return res
  end
  local len = self.rfd:read(4)
  if len then
    len = bit32.lshift(string.byte(string.sub(len, 4, 4)), 24) +
    bit32.lshift(string.byte(string.sub(len, 3, 3)), 16) +
    bit32.lshift(string.byte(string.sub(len, 2, 2)), 8) +
    string.byte(string.sub(len, 1, 1))
    local frame = self.rfd:read(len)
    return frame
  end
  return nil
end

--- Format and write message in output file
-- @tparam string msg Message
function fbuffer_mt.__index:WriteMessage(msg)
  self.wfd:write(string.char(bit32.band(#msg, 0xff),
      bit32.band(bit32.rshift(#msg, 8), 0xff),
      bit32.band(bit32.rshift(#msg, 16), 0xff),
      bit32.band(bit32.rshift(#msg, 24), 0xff)))
  self.wfd:write(msg)
end

--- Flush data in output file
function fbuffer_mt.__index:Flush()
  self.wfd:flush()
end

--- Type which provides file-stream for continuous communications ATF and SDL
-- @type FileStream

--- Construct instance of FileStream type
-- @tparam string filename File name which used as buffer
-- @tparam number version SDL protocol version
-- @tparam string sessionId Mobile session identifier
-- @tparam string service Mobile service identifier
-- @tparam boolean encryption True in case of encrypted streaming
-- @tparam number bandwidth Bandwidth in bytes
-- @treturn FileStream Constructed instance
function MD.FileStream(filename, version, sessionId, service, encryption, bandwidth)
  local errmsg
  local res = { }
  res.filename = filename
  res.version = version
  res.service = service
  res.sessionId = sessionId
  res.encryption = encryption
  res.bandwidth = bandwidth
  res.bytesSent = 0
  res.ts = timestamp()

  local frameSize = (constants.FRAME_SIZE["P" .. res.version]
      - constants.PROTOCOL_HEADER_SIZE)

  res.chunksize = (frameSize < bandwidth) and frameSize or (bandwidth - 1)
  res.protocol_handler = ph.ProtocolHandler()
  res.messageId = 1
  res.rfd, errmsg = io.open(filename, "r")
  if not res.rfd then error (errmsg) end
  setmetatable(res, fstream_mt)
  return res
end

--- Suspend message in stream
-- @tparam string msg Message
function fstream_mt.__index:KeepMessage(msg)
  self.keep = msg
end

--- Construct message to SDL
-- @treturn table Ford protocol frame
-- @treturn number timeout Timeout for next message
function fstream_mt.__index:GetMessage()
  local timespan = timestamp() - self.ts
  if timespan > 5000 then
    self.ts = self.ts + timespan - 1000
    self.bytesSent = self.bytesSent / (timespan / 1000)
    timespan = 1000
  end
  if (self.bytesSent + self.chunksize) / (timespan / 1000) > self.bandwidth then
    return nil, 200
  end
  local res = nil
  if self.keep then
    res = self.keep
    self.keep = nil
    return res, nil
  end
  local data = self.rfd:read(self.chunksize)
  if data then
    self.bytesSent = self.bytesSent + #data
    self.messageId = self.messageId + 1

    local header =
    {
      version = self.version,
      encryption = self.encryption,
      sessionId = self.sessionId,
      frameInfo = 0,
      frameType = 1,
      serviceType = self.service,
      binaryData = data,
      messageId = self.messageId
    }

    res = table.concat(self.protocol_handler:Compose(header))
  end
  return res, nil
end

--- Type which provides low level handling of communications between ATF and SDL
-- @type MessageDispatcher

--- Construct instance of MessageDispatcher type
-- @tparam FileConnection connection File connection
-- @treturn MessageDispatcher Constructed instance
function MD.MessageDispatcher(connection)
  local res = {}
  res._d = qt.dynamic()
  res.generators = { }
  res.idx = 0
  res.connection = connection
  res.bufferSize = constants.FRAME_SIZE["P" .. config.defaultProtocolVersion]
  -- res.bufferSize = 8192 -- previous hardcoded value
  res.mapped = { }
  res.timer = timers.Timer()
  res.sender = qt.dynamic()

  function res._d:timeout()
    self:bytesWritten(0)
  end

  function res.sender:SignalMessageSent() end

  -- Prepare binary message for send it by tcp
  -- c count of bytes
  function res._d:bytesWritten(c)
    if #res.generators == 0 then return end
    res.bufferSize = res.bufferSize + c
    for _ = 1, #res.generators do
      if res.idx < #res.generators then
        res.idx = res.idx + 1
      else
        res.idx = 1
      end
      local msg, timeout = res.generators[res.idx]:GetMessage()
      if msg and #msg > 0 then
        if res.bufferSize >= #msg then
          res.bufferSize = res.bufferSize - #msg
          res.connection:Send({ msg })
          break
        else
          res.generators[res.idx]:KeepMessage(msg)
        end
      elseif timeout then
        res.timer:start(timeout)
      end
    end
  end

  res.timer:setSingleShot(true)
  res.connection:OnDataSent(function(_, num) res._d:bytesWritten(num) end)
  qt.connect(res.timer, "timeout()", res._d, "timeout()")
  setmetatable(res, MD.mt)
  return res
end

--- Set handler for OnMessageSent
-- @tparam function func Handler function
function MD.mt.__index:OnMessageSent(func)
  local d = qt.dynamic()

  function d:SlotMessageSent(v)
    func(v)
  end

  qt.connect(self.sender, "SignalMessageSent(int)", d, "SlotMessageSent(int)")
end

--- Add filebuffer to generators
-- @tparam FileStorage filebuffer File buffer
function MD.mt.__index:MapFile(filebuffer)
  self.mapped[filebuffer.filename] = filebuffer
  table.insert(self.generators, filebuffer)
end

--- Remove filebuffer from generators
-- @tparam FileStorage filebuffer File buffer
function MD.mt.__index:UnmapFile(filebuffer)
  if not filebuffer then
    error("File was not mapped")
  end
  self.mapped[filebuffer.filename] = nil
  for i, g in ipairs(self.generators) do
    if g == filebuffer then
      table.remove(self.generators, i)
      break
    end
  end
end

--- Send pack of messages
function MD.mt.__index:Pulse()
  self._d:bytesWritten(0)
end

return MD
