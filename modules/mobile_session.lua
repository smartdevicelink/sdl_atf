--- Module which provides interface for emulate mobile session
--
-- *Dependencies:* `atf.util`, `mobile_session_impl`
--
-- *Globals:* `config`
-- @module mobile_session
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('atf.util')
local mobile_session_impl = require('mobile_session_impl')

local MS = {}
local mt = { __index = { } }

--- Type which provides interface for emulate mobile session
-- @type MobileSession

--- Expectation of specific event
-- @tparam Event event Expected event
-- @tparam string name Event name
-- @treturn Expectation Expectation for event
function mt.__index:ExpectEvent(event, name)
  return self.mobile_session_impl:ExpectEvent(event, name)
end

--- Expectation of any event
-- @treturn Expectation Expectation for any unprocessed event
function mt.__index:ExpectAny()
  return self.mobile_session_impl:ExpectAny()
end

--- Expectation of packet event
-- @tparam table frameMessage Packet message to expect
-- @tparam function binaryDataCompareFunc Function used for binary data comparation
-- @treturn Expectation Expectation for packet event
function mt.__index:ExpectPacket(frameMessage, binaryDataCompareFunc)
  return self.mobile_session_impl:ExpectFrame(frameMessage, binaryDataCompareFunc)
end

--- Expectation of request
-- @tparam number funcName Expected request name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for request
function mt.__index:ExpectRequest(funcName, ...)
  return self.mobile_session_impl:ExpectRequest(funcName, ...)
end

--- Expectation of response with specific correlation_id
-- @tparam number cor_id Correlation identifier of specific rpc event
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for response
function mt.__index:ExpectResponse(cor_id, ...)
  return self.mobile_session_impl:ExpectResponse(cor_id, ...)
end

--- Expectation of notification with specific funcName
-- @tparam string funcName Expected notification name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for notification
function mt.__index:ExpectNotification(funcName, ...)
   return self.mobile_session_impl:ExpectNotification(funcName, ...)
end

--- Expectation of encrypted request with specific funcName
-- @tparam number funcName Expected request name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for response
function mt.__index:ExpectEncryptedRequest(funcName, ...)
  return self.mobile_session_impl:ExpectEncryptedRequest(funcName, ...)
end

--- Expectation of encrypted response with specific correlation_id
-- @tparam number cor_id Correlation identifier of specific rpc event
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for response
function mt.__index:ExpectEncryptedResponse(cor_id, ...)
  return self.mobile_session_impl:ExpectEncryptedResponse(cor_id, ...)
end

--- Expectation of encrypted notification with specific funcName
-- @tparam string funcName Expected notification name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation for notification
function mt.__index:ExpectEncryptedNotification(funcName, ...)
   return self.mobile_session_impl:ExpectEncryptedNotification(funcName, ...)
end

--- Start encrypted audio/video streaming
-- @tparam number service Service type
-- @tparam string filename File for streaming
-- @tparam ?number bandwidth Bandwidth in bytes (default value is 30 * 1024)
function mt.__index:StartEncryptedStreaming(service, filename, bandwidth)
  self.mobile_session_impl:StartEncryptedStreaming(self.SessionId.get(), service, filename, bandwidth)
end

--- Start audio/video streaming
-- @tparam number service Service type
-- @tparam string filename File for streaming
-- @tparam ?number bandwidth Bandwidth in bytes (default value is 30 * 1024)
function mt.__index:StartStreaming(service, filename, bandwidth)
  self.mobile_session_impl:StartStreaming(self.SessionId.get(), service, filename, bandwidth)
end

--- Stop audio/video streaming
-- @tparam string filename File for streaming
function mt.__index:StopStreaming(filename)
  self.mobile_session_impl:StopStreaming(filename)
end

--- Send RPC
-- @tparam string func RPC name
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendRPC(func, arguments, fileName)
  return self.mobile_session_impl:SendRPC(func, arguments, fileName)
end

--- Send RPC response
-- @tparam string func RPC name
-- @tparam string cor_id Correlation identifier
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendResponse(func, cor_id, arguments, fileName)
  return self.mobile_session_impl:SendResponse(func, cor_id, arguments, fileName)
end

--- Send notification
-- @tparam string func RPC name
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendNotification(func, arguments, fileName)
  return self.mobile_session_impl:SendNotification(func, arguments, fileName)
end

--- Send encrypted RPC
-- @tparam string func RPC name
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendEncryptedRPC(func, arguments, fileName)
  return self.mobile_session_impl:SendEncryptedRPC(func, arguments, fileName)
end

--- Send encrypted RPC response
-- @tparam string func RPC name
-- @tparam string cor_id Correlation identifier
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendEncryptedResponse(func, cor_id, arguments, fileName)
  return self.mobile_session_impl:SendEncryptedResponse(func, cor_id, arguments, fileName)
end

--- Send encrypted notification
-- @tparam string func RPC name
-- @tparam table arguments Arguments for RPC function
-- @tparam string fileName Path to file with binary data
function mt.__index:SendEncryptedNotification(func, arguments, fileName)
  return self.mobile_session_impl:SendEncryptedNotification(func, arguments, fileName)
end


---Start specific service
-- For service == 7 should be used StartRPC() instead of this function
-- @tparam number service Service type
-- @treturn Expectation expectation for StartService ACK
function mt.__index:StartService(service)
  if service == 7 then
    return self:StartRPC()
  end
  -- in case StartService(7) it should be change on StartRPC
  return self.mobile_session_impl:StartService(service)
end

---Start specific secure service
-- @tparam number service Service type
-- @treturn Expectation expectation for StartService ACK
function mt.__index:StartSecureService(service)
  return self.mobile_session_impl:StartSecureService(service)
end

---Stop specific service
-- @tparam number service Service type
-- @treturn Expectationexpectation for EndService ACK
function mt.__index:StopService(service)
  if service == 7 then
    return self.mobile_session_impl:StopRPC()
  end
  return self.mobile_session_impl:StopService(service)
end

--- Stop heartbeat from mobile side
function mt.__index:StopHeartbeat()
  self.mobile_session_impl:StopHeartbeat()
end

--- Start heartbeat from mobile side
function mt.__index:StartHeartbeat()
  self.mobile_session_impl:StartHeartbeat()
end

--- Set timeout for heartbeat
-- @tparam number timeout Timeout for heartbeat
function mt.__index:SetHeartbeatTimeout(timeout)
  self.mobile_session_impl:SetHeartbeatTimeout(timeout)
end

--- Start RPC service and heartBeat
-- @tparam table custom_hb_processor Heartbeat processor
-- @treturn Expectation Expectation for StartService ACK
function mt.__index:StartRPC(custom_hb_processor)
  custom_hb_processor = custom_hb_processor
    or function (_,_)
      -- empty
    end
  return self.mobile_session_impl:StartRPC():Do(custom_hb_processor)
end

--- Stop RPC service
function mt.__index:StopRPC()
  return self.mobile_session_impl:StopRPC()
end

--- Send message from mobile to SDL
-- @tparam table message Data to be sent
function mt.__index:Send(message)
  -- Workaround
    if message.serviceType == 7 then
      self.mobile_session_impl.rpc_services:CheckCorrelationID(message)
    end
  --
  self.mobile_session_impl:Send(message)
  return message
end

--- Send frame from mobile to SDL
-- @tparam string bytes Bytes to be sent
function mt.__index:SendPacket(message)
  self.mobile_session_impl:SendFrame(message)
end

--- Start rpc service (7) and send RegisterAppInterface rpc
-- @treturn Expectation Expectation for session is started and app is registered
function mt.__index:Start()
  return self.mobile_session_impl:Start()
end

--- Stop rpc service (7) and stop Heartbeat
-- @treturn Expectation Expectation for stop session
function mt.__index:Stop()
  return self.mobile_session_impl:Stop()
end

--- Construct instance of MobileSession type
-- @tparam Test test Test which open mobile session
-- @tparam MobileConnection connection Base connection for open mobile session
-- @tparam table regAppParams Mobile application parameters
-- @tparam table securitySettings Session security parameters
-- @treturn MobileSession Constructed instance
function MS.MobileSession(test, connection, regAppParams, securitySettings)
  local res = { }
  res.correlationId = 1
  res.sessionId = 0

  --- Session identifier
  res.SessionId = {}
  function res.SessionId.set(val)
    res.sessionId = val
  end
  function res.SessionId.get()
    return res.sessionId
  end

  --- Correlation identifier
  res.CorrelationId = {}
  function res.CorrelationId.set(val)
    res.correlationId = val
  end
  function res.CorrelationId.get()
    return  res.correlationId
  end

  --- Flag which defines whether mobile session activates heartbeat
  res.activateHeartbeat = true
  --- Flag which defines whether mobile session sends heartbeat to SDL
  res.sendHeartbeatToSDL = true
  --- Flag which defines whether mobile session answers on heartbeat from SDL
  res.answerHeartbeatFromSDL = true
  --- Flag which defines whether mobile session ignore ACK of heartbeat from SDL
  res.ignoreSDLHeartBeatACK = false

  --- Property which defines whether mobile session activates heartbeat
  res.ActivateHeartbeat = {}
  function res.ActivateHeartbeat.get()
    return res.activateHeartbeat
  end

  --- Property which defines whether mobile session sends heartbeat to SDL
  res.SendHeartbeatToSDL = {}
  function res.SendHeartbeatToSDL.get()
    return res.sendHeartbeatToSDL
  end

  --- Property which defines whether mobile session answers on heartbeat from SDL
  res.AnswerHeartbeatFromSDL = {}
  function res.AnswerHeartbeatFromSDL.get()
    return res.answerHeartbeatFromSDL
  end

  --- Property which defines whether mobile session ignore ACK of heartbeat from SDL
  res.IgnoreSDLHeartBeatAck = {}
  function res.IgnoreSDLHeartBeatAck.get()
    return res.ignoreSDLHeartBeatACK
  end

  --- Accessor of isSecuredSession variable
  function res:IsSecuredSession()
    return self.mobile_session_impl.isSecuredSession
  end

  securitySettings = securitySettings or {
    cipherListString = config.cipherListString,
    serverCertPath = config.serverCertificatePath,
    serverKeyPath = config.serverPrivateKeyPath,
    serverCAChainCertPath = config.serverCAChainCertPath,
    isCheckClientCertificate = config.isCheckClientCertificate,
    securityProtocol = config.SecurityProtocol,
    isHandshakeDisplayed = false
  }

  --- Accessor of mobile_session_impl
  res.mobile_session_impl = mobile_session_impl.MobileSessionImpl(
      res.SessionId, res.CorrelationId, test, connection, securitySettings, res.ActivateHeartbeat,
      res.SendHeartbeatToSDL, res.AnswerHeartbeatFromSDL, res.IgnoreSDLHeartBeatAck, regAppParams )
  setmetatable(res, mt)
  return res
end

return MS
