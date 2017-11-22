--- Module which provides implementation for mobile session interface
--
-- *Dependencies:* `atf.util`, `expectations`, `events`, `services.control_service`,
-- `services.rpc_service`, `services.heartbeat_monitor`, `expectations.session_expectations`
--
-- *Globals:* `config`, 'xmlReporter'
-- @module mobile_session_impl
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('atf.util')
local expectations = require('expectations')
local events = require('events')
local control_services = require('services/control_service')
local rpc_services = require('services/rpc_service')
local heartbeatMonitor = require('services/heartbeat_monitor')
local mobileExpectations = require('expectations/session_expectations')
local constants = require('protocol_handler/ford_protocol_constants')

local FAILED = expectations.FAILED
local MSI = {}
local mt = { __index = { } }

--- Type which provides interface for emulate mobile session
-- @type MobileSessionImpl

--- Expectation of specific event
-- @tparam Event event Expected event
-- @tparam string name Event name
-- @treturn Expectation Expectation for event
function mt.__index:ExpectEvent(event, name)
  return self.mobile_expectations:ExpectEvent(event, name)
end

--- Expectation of any event
-- @treturn Expectation Expectation for any unprocessed event
function mt.__index:ExpectAny()
  return self.mobile_expectations:ExpectAny()
end

--- Expectation of responce with specific correlation_id
-- @tparam number cor_id Correlation identifier of specific rpc event
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for response
function mt.__index:ExpectResponse(cor_id, ...)
  return self.rpc_services:ExpectResponse(cor_id, ...)
end

--- Expectation of notification with specific funcName
-- @tparam string funcName Expected notification name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for notification
function mt.__index:ExpectNotification(funcName, ...)
   return self.rpc_services:ExpectNotification(funcName, ...)
end

--- Start video streaming
-- @tparam number session_id Mobile session identifier
-- @tparam number service Service type
-- @tparam string filename File for streaming
-- @tparam ?number bandwidth Bandwidth in bytes (default value is 30 * 1024)
function mt.__index:StartStreaming(session_id, service, filename, bandwidth)
  self.connection:StartStreaming(session_id, service, filename, bandwidth)
end

--- Stop video streaming
-- @tparam string filename File for streaming
function mt.__index:StopStreaming(filename)
  self.connection:StopStreaming(filename)
end

--- Send RPC
-- @tparam string func RPC name
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendRPC(func, arguments, fileName)
  return self.rpc_services:SendRPC(func, arguments, fileName)
end

---Start specific service
-- For service == 7 should be used StartRPC() instead of this function
-- @tparam number service Service type
-- @treturn Expectation expectation for StartService ACK
function mt.__index:StartService(service)
  return self.control_services:StartService(service)
end

---Stop specific service
-- @tparam number service Service type
-- @treturn Expectationexpectation for EndService ACK
function mt.__index:StopService(service)
  return self.control_services:StopService(service)
end

--- Stop heartbeat from mobile side
function mt.__index:StopHeartbeat()
  self.heartbeat_monitor:StopHeartbeat()
end

--- Start heartbeat from mobile side
function mt.__index:StartHeartbeat()
  if self.activateHeartbeat.get() then
    self.heartbeat_monitor:StartHeartbeat()
  end
end

--- Set timeout for heartbeat
-- @tparam number timeout Timeout for heartbeat
function mt.__index:SetHeartbeatTimeout(timeout)
  self.heartbeat_monitor:SetHeartbeatTimeout(timeout)
end

--- Start RPC service and heartBeat
-- @treturn Expectation Expectation for StartService ACK
function mt.__index:StartRPC()
  local ret = self:StartService(constants.SERVICE_TYPE.RPC)
  ret:Do(function()
      -- Heartbeat
      if self.version > 2 then
        self.heartbeat_monitor:StartHeartbeat()
      end
    end)
  ret:Do(function(s, data)
    if s.status == FAILED then return end
    self.sessionId.set(data.sessionId)
    self.hashCode = data.binaryData

    -- Heartbeat
    if self.version > 2 then
      self:StartHeartbeat()
    end
  end)
  return ret
end

--- Stop RPC service
function mt.__index:StopRPC()
  local ret = self.control_services:StopService(constants.SERVICE_TYPE.RPC)
  self:StopHeartbeat()
  return ret
end

--- Send message from mobile to SDL
-- @tparam table message Data to be sent
function mt.__index:Send(message)
  if not message.serviceType then
    error("MobileSession:Send: serviceType must be specified")
  end
  if not message.frameInfo then
    error("MobileSession:Send: frameInfo must be specified")
  end

  self.messageId = self.messageId + 1
  message.version = message.version or self.version
  message.encryption = message.encryption or false
  message.frameType = message.frameType or 1
  message.sessionId = self.sessionId.get()
  message.messageId = self.messageId


  self.connection:Send({message})
  xmlReporter.AddMessage("MobileSession","Send",{message})

  if self.activateHeartbeat.get() then
    self.heartbeat_monitor:OnMessageSent(message)
  end

  return message
end

--- Start rpc service (7) and send RegisterAppInterface rpc
function mt.__index:Start()
  self:StartRPC()
  :Do(function()
    local correlationId = self:SendRPC("RegisterAppInterface", self.regAppParams)
    self:ExpectResponse(correlationId, { success = true })
    end)
end

--- Stop rpc service (7) and stop Heartbeat
function mt.__index:Stop()
  self:StopRPC()
end

--- Construct instance of MobileSessionImpl type
-- @tparam number session_id Mobile session identifier
-- @tparam number correlation_id Initial correlation identifier
-- @tparam Test test Test which open mobile session
-- @tparam MobileConnection connection Base connection for open mobile session
-- @tparam table activateHeartbeat  Access table for activation of heartbeat to SDL flag
-- @tparam table sendHeartbeatToSDL Access table for send heartbeat to SDL flag
-- @tparam table answerHeartbeatFromSDL Access table for answer heartbeat from SDL flag
-- @tparam table ignoreHeartBeatAck Access table for ignore heartbeat ACK from SDL flag
-- @tparam table regAppParams Mobile application parameters
-- @treturn MobileSessionImpl Constructed instance
function MSI.MobileSessionImpl(session_id, correlation_id, test, connection, activateHeartbeat,
    sendHeartbeatToSDL, answerHeartbeatFromSDL, ignoreHeartBeatAck, regAppParams)
  local res = { }
  --- Test which open mobile session
  res.test = test
  --- Mobile application parameters for its registration
  res.regAppParams = regAppParams
  --- Mobile connection
  res.connection = connection
  --- List of registered expectations
  res.exp_list = test.expectations_list
  --- Message identifier
  res.messageId = 1
  --- Ford protocol version
  res.version = config.defaultProtocolVersion or 2
  --- Mobile application state hashcode
  res.hashCode = 0
  --- Correlation identifier
  res.correlationId = correlation_id
  --- Mobile session identifier
  res.sessionId = session_id
  --- Control services handler
  res.control_services =  control_services.Service(res)
  --- RPC services handler
  res.rpc_services = rpc_services.RPCService(res)
  --- Mobile expectations handler
  res.mobile_expectations = mobileExpectations.MobileExpectations(res)
    --- Access table for activation state of heartbeat to SDL flag
  res.activateHeartbeat = activateHeartbeat
  --- Access table for send heartbeat to SDL flag
  res.sendHeartbeatToSDL = sendHeartbeatToSDL
  --- Access table for answer heartbeat from SDL flag
  res.answerHeartbeatFromSDL = answerHeartbeatFromSDL
  --- Access table for ignore heartbeat ACK from SDL flag
  res.ignoreHeartBeatAck = ignoreHeartBeatAck
  --- Heartbeat monitor
  res.heartbeat_monitor = heartbeatMonitor.HeartBeatMonitor(res)
  setmetatable(res, mt)
  return res
end

return MSI
