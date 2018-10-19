--- Module which is responsible for all heartbeat emulation activities and provides HeartBeatMonitor type
--
-- *Dependencies:* `events`, `protocol_handler.ford_protocol_constants`, `qt`, `timers`
--
-- *Globals:* `xmlReporter`, `AnyNumber()`, `qt`, `timers`
-- @module services.heartbeat_monitor
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local events = require('events')
local constants = require('protocol_handler/ford_protocol_constants')

local HbMonitor = {}
local mt = { __index = { } }

--- Type which represents Heartbeat monitor. It responsible for all heartbeat emulation activities.
-- @type HeartBeatMonitor

--- Check whether message is heartbeat
-- @tparam table message Message for check
-- @treturn boolean True if message is heartbeat
local function isHeartbeatMessage(message)
  return message.frameType == constants.FRAME_TYPE.CONTROL_FRAME
    and message.serviceType == constants.SERVICE_TYPE.CONTROL
    and message.frameInfo == constants.FRAME_INFO.HEARTBEAT
end

--- Check whether message is heartbeat ACK
-- @tparam table message Message for check
-- @treturn boolean True if message is heartbeat ACK
local function isHeartbeatAckMessage(message)
  return message.frameType == constants.FRAME_TYPE.CONTROL_FRAME
    and message.serviceType == constants.SERVICE_TYPE.CONTROL
    and message.frameInfo == constants.FRAME_INFO.HEARTBEAT_ACK
end

--- Create and register expectation for heartbeat ACK from SDL
-- @tparam HeartBeatMonitor heartBeatMonitor Heartbeat monitor instance
local function ExpectHeartbeatAck(heartBeatMonitor)
  local event = events.Event()
  event.matches = function(_, data)
    return data.sessionId == heartBeatMonitor.session.sessionId.get()
      and isHeartbeatAckMessage(data)
  end
  heartBeatMonitor.expectations:ExpectEvent(event, "HeartbeatACK")
  :Do(function(_, _)
      heartBeatMonitor.isHeartbeatConfirmedBySDL = true
    end)
end

--- Send Heartbeat to SDL
-- @tparam HeartBeatMonitor heartBeatMonitor Heartbeat monitor instance
local function SendHeartbeat(heartBeatMonitor)
  heartBeatMonitor.control_services:SendControlMessage( {frameInfo = constants.FRAME_INFO.HEARTBEAT } )
end

--- Send Heartbeat ACK to SDL
-- @tparam HeartBeatMonitor heartBeatMonitor Heartbeat monitor instance
local function SendHeartbeatAck(heartBeatMonitor)
  heartBeatMonitor.control_services:SendControlMessage( {frameInfo = constants.FRAME_INFO.HEARTBEAT_ACK } )
end

--- Create and register expectation for heartbeat
-- @tparam HeartBeatMonitor heartBeatMonitor Heartbeat monitor instance
local function AddHeartbeatExpectation(heartBeatMonitor)
  local event = events.Event()
  event.matches = function(_, data)
    return data.sessionId == heartBeatMonitor.session.sessionId.get()
      and isHeartbeatMessage(data)
  end
  heartBeatMonitor.expectations:ExpectEvent(event, "Heartbeat")
  :Pin()
  :Times(AnyNumber())
  :Do(function(_, _)
      if heartBeatMonitor.heartbeatEnabled and heartBeatMonitor.AnswerHeartbeatFromSDL.get() then
        SendHeartbeatAck(heartBeatMonitor)
      end
    end)
end

--- Start heartbeat
function mt.__index:StartHeartbeat()
  if not self.heartbeatEnabled then
    self.heartbeatEnabled = true
    if not self.isHeartbeatConfirmedBySDL then
      if self.IgnoreHeartBeatAck.get() then
        self.isHeartbeatConfirmedBySDL = true
      else
        ExpectHeartbeatAck(self)
      end

      AddHeartbeatExpectation(self)
    end

    if not self.heartbeatToSDLTimerRegistered then
      qt.connect(self.heartbeatToSDLTimer, "timeout()", self.qtproxy, "SendHeartbeat()")
      self.heartbeatToSDLTimerRegistered = true
    end

    if self.SendHeartbeatToSDL.get() then
      self.heartbeatToSDLTimer:start(self.heartbeatTimeout)
      self.heartbeatToSDLTimerStarted = true
    end

    SendHeartbeat(self)
    xmlReporter.AddMessage("StartHearbeat", "True", (self.heartbeatTimeout))
  end
end

--- Stop heartbeat
function mt.__index:StopHeartbeat()
  if self.heartbeatEnabled then
    self.heartbeatEnabled = false

    if self.heartbeatToSDLTimerStarted then
      self.heartbeatToSDLTimer:stop()
    end

    xmlReporter.AddMessage("StopHearbeat", "True")
  end
end

--- Set heartbeat interval
-- @tparam number timeout Heartbeat interval in msec
function mt.__index:SetHeartbeatTimeout(timeout)
  self.heartbeatTimeout = timeout
  self.heartbeatToSDLTimer:setInterval(timeout)
end

--- Callback on sent message event
-- @tparam table message Message which was sent
function mt.__index:OnMessageSent(message)
  if not (isHeartbeatMessage(message) or isHeartbeatAckMessage(message))
      and self.heartbeatToSDLTimerStarted then
    self.heartbeatToSDLTimer:reset()
  end
end

--- Construct instance of HeartBeatMonitor type
-- @tparam MobileSession session Mobile session
-- @treturn HeartBeatMonitor Constructed instance
function HbMonitor.HeartBeatMonitor(session)
  local res = { }
  res.qtproxy = qt.dynamic()

  function res.qtproxy.SendHeartbeat()
    if res.heartbeatEnabled and res.SendHeartbeatToSDL.get() then
      SendHeartbeat(res)
    end
  end

  res.heartbeatTimeout = config.heartbeatTimeout
  res.session = session
  res.sessionId = session.sessionId
  res.control_services = session.control_services
  res.expectations = session.mobile_expectations

  res.heartbeatToSDLTimer = timers.Timer()

  res.SendHeartbeatToSDL = {}
  function res.SendHeartbeatToSDL.get()
    return session.sendHeartbeatToSDL.get()
  end

  res.AnswerHeartbeatFromSDL = {}
  function res.AnswerHeartbeatFromSDL.get()
    return session.answerHeartbeatFromSDL.get()
  end

  res.IgnoreHeartBeatAck = {}
  function res.IgnoreHeartBeatAck.get()
    return session.ignoreHeartBeatAck.get()
  end

  res.heartbeatEnabled = false
  res.isHeartbeatConfirmedBySDL = false
  res.heartbeatToSDLTimerRegistered = false
  res.heartbeatToSDLTimerStarted = false
  setmetatable(res, mt)
  return res
end

return HbMonitor
