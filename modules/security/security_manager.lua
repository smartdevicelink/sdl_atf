--- Module which provide SecurityManager type
--
-- *Dependencies:* `luaopenssl`, `security.security_constants`
--
-- *Globals:* none
-- @module security.security_constants
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local openssl = require('luaopenssl')
local securityConstants = require('security/security_constants')

local SecurityManager = {}

--- Update mobile session property 'isSecuredSession' according to secured services
local function updateSecurityOfSession(security)
  if next(security.encryptedServices) == nil then
    security.session.isSecuredSession = false
    security.ctx = nil
    security.ssl = nil
    security.bioIn = nil
    security.bioOut = nil
  else
    security.session.isSecuredSession = true
  end
end

--- Get security protocol type
-- @treturn number Return number representation of security protocol type
local function getSecurityProtocolConst(strProtocol)
  local protocolConst = securityConstants.PROTOCOLS[strProtocol]
  return protocolConst or securityConstants.PROTOCOLS.AUTO
end

--- Type which perform security activities for mobile session
-- @type Security

local security_mt = { __index = {} }

--- Check is SSL handshake finished
-- @treturn boolean True if SSL handshake was finished
function security_mt.__index:isHandshakeFinished()
  if self.ssl then
    return self.ssl:isHandshakeFinished()
  end
  return false
end

--- Prepare openssl to perform SSL handshake on base of securitySettings
function security_mt.__index:prepareToHandshake()
  if not self.ssl or self:isHandshakeFinished() then
    local SERVER = 1
    self.ctx = SecurityManager.createSslContext(self)
    self.bioIn = SecurityManager.createBio(securityConstants.BIO_TYPES.SOURCE, self)
    self.bioOut = SecurityManager.createBio(securityConstants.BIO_TYPES.SOURCE, self)
    self.ssl = self.ctx:newSsl()

    if self.settings.isHandshakeDisplayed then
      self.ssl:setInfoCallback(SERVER)
    end

    self.ssl:setBios(self.bioIn, self.bioOut)
    self.ssl:prepareToHandshake(SERVER)
  end
end

--- Start/continue SSL handshake
-- @tparam string inHandshakeData Incoming binary handshake data
-- @treturn string Outgoing binary handshake data
function security_mt.__index:performHandshake(inHandshakeData)
  local outHandshakeData = nil
  if not self:isHandshakeFinished()
     and inHandshakeData and inHandshakeData:len() > 0 then
    self.bioIn:write(inHandshakeData);
    self.ssl:performHandshake()
    local pending = self.bioOut:checkData()
    if pending > 0 then
      outHandshakeData = self.bioOut:read(pending)
    end
  end
  return outHandshakeData
end

--- Encrypt binary data
-- @tparam string data Incoming binary data
-- @treturn number Encryption status
-- @treturn string Outgoing encrypted binary data
function security_mt.__index:encrypt(data)
  if not (self:isHandshakeFinished() and data) then
    return securityConstants.SECURITY_STATUS.ERROR, nil
  end

  self.ssl:encrypt(data)
  local pending = self.bioOut:checkData()
  if pending == 0 then
    return securityConstants.SECURITY_STATUS.ERROR, nil
  end

  local encryptedData = self.bioOut:read(pending)
  if not encryptedData then
    return securityConstants.SECURITY_STATUS.ERROR, nil
  end

  return securityConstants.SECURITY_STATUS.SUCCESS, encryptedData
end

--- Decrypt binary data
-- @tparam string encryptedData Incoming encrypted binary data
-- @treturn number Decryption status
-- @treturn string Outgoing binary data
function security_mt.__index:decrypt(encryptedData)
  if not (self:isHandshakeFinished()
     and encryptedData and encryptedData:len() > 0) then
    return securityConstants.SECURITY_STATUS.ERROR, nil
  end

  self.bioIn:write(encryptedData)
  local pending = self.ssl:checkData()
  if pending == 0 then
    return securityConstants.SECURITY_STATUS.ERROR, nil
  end

  local data = self.ssl:decrypt(pending)
  if not data then
    return securityConstants.SECURITY_STATUS.ERROR, nil
  end

  return securityConstants.SECURITY_STATUS.SUCCESS, data
end

--- Register mobile session security into Security manager as secure
function security_mt.__index:registerSessionSecurity()
  if not SecurityManager.mobileSecurities[self.session.sessionId.get()] then
    SecurityManager.mobileSecurities[self.session.sessionId.get()] = self
  end
end

function security_mt.__index:unregisterSessionSecurity()
  SecurityManager.mobileSecurities[self.session.sessionId.get()] = nil
end

--- Register service into mobile session security. Service assumed as secure
-- @tparam number service Service number
function security_mt.__index:registerSecureService(service)
  self.encryptedServices[service] = true
  updateSecurityOfSession(self)
end

--- Unregister service into mobile session security. Service assumed as not secure
-- @tparam number service Service number
function security_mt.__index:unregisterSecureService(service)
  self.encryptedServices[service] = nil
  updateSecurityOfSession(self)
end

--- Unregister all registered services into mobile session security. All services assumed as not secure
function security_mt.__index:unregisterAllSecureServices()
  self.encryptedServices = {}
  updateSecurityOfSession(self)
end

--- Unregister service into mobile session security. Service assumed as not secure
-- @tparam number service Service number
function security_mt.__index:checkSecureService(service)
  return self.encryptedServices[service]
end

--- Type which perform security manager activities for ATF
-- @type SecurityManager

SecurityManager.mobileSecurities = {}

--- Initialize ATF security manager
function SecurityManager.init()
  openssl.initSslLibrary()
end

--- Create and initialize instance of SSL context for mobile session
-- @tparam table sessionSecurity Security instance of mobile session
-- @treturn userdata SSL context instance
function SecurityManager.createSslContext(sessionSecurity)
  local sslCtx = openssl.newSslContext(getSecurityProtocolConst(sessionSecurity.settings.securityProtocol))
  if (not (sslCtx and sslCtx:initSslContext(
                sessionSecurity.settings.cipherListString,
                sessionSecurity.settings.serverCertPath,
                sessionSecurity.settings.serverKeyPath,
                sessionSecurity.settings.serverCAChainCertPath,
                sessionSecurity.settings.isCheckClientCertificate))) then
    error("Error: Can not create and init SSL context for mobile session " .. sessionSecurity.session.sessionId.get())
  end
  return sslCtx
end

--- Create instance of BIO
-- @tparam number bioType Type of BIO
-- @tparam table sessionSecurity Security instance of mobile session
-- @treturn userdata BIO instance
function SecurityManager.createBio(bioType, sessionSecurity)
  local bio = openssl.newBio(bioType)
  if not bio then
    error("Error: Can not create BIO for mobile session " .. sessionSecurity.session.sessionId.get())
  end
  return bio
end

--- Decrypt binary data
-- @tparam string encryptedData Incoming encrypted binary data
-- @tparam number sessionId Identifier of mobile session
-- @tparam number serviceType Service number
-- @treturn number Decryption status
-- @treturn string Outgoing binary data
function SecurityManager:decrypt(encryptedData, sessionId, serviceType, isStartServiceAck)
  local security = self.mobileSecurities[sessionId]
  if not security then
    print("Error [decrypt]: Session " .. sessionId .. " is not registered in ATF Security manager")
    return securityConstants.SECURITY_STATUS.ERROR, encryptedData
  end
  if not security:checkSecureService(serviceType) and not isStartServiceAck then
    print("Warning: Received encrypted message with not secure service: " .. serviceType)
  end
  return security:decrypt(encryptedData)
end

--- Encrypt binary data
-- @tparam string data Incoming binary data
-- @tparam number sessionId Identifier of mobile session
-- @tparam number serviceType Service number
-- @treturn number Encryption status
-- @treturn string Outgoing encrypted binary data
function SecurityManager:encrypt(data, sessionId, serviceType)
  local security = self.mobileSecurities[sessionId]
  if not security then
    error("Error [encrypt]: Session " .. sessionId .. " is not registered in ATF Security manager")
  end
  if not security:checkSecureService(serviceType) then
    error("Error: Try to send encrypted message with not secure service" .. serviceType)
  end
  return security:encrypt(data)
end

--- Construct instance of Security
-- @tparam MobileSessionImpl mobileSession Mobile session instance
-- @tparam table securitySettings Settings for security instance
-- @treturn Security Constructed instance
function SecurityManager:Security(mobileSession, securitySettings)
  local res = {}
  res.settings = securitySettings
  res.session = mobileSession
  res.encryptedServices = {}
  res.isEncryptedSession = nil
  res.ctx = nil
  res.ssl = nil
  res.bioIn = nil
  res.bioOut = nil
  setmetatable(res, security_mt)
  return res
end

SecurityManager.init()
return SecurityManager
