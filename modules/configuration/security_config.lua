--- Module which provides ATF security configuration
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local config = { }

--- Security
--
--- Define security protocol
config.SecurityProtocol = "DTLS"
--- Define ciphers
config.cipherListString = "ALL:!ADH:!LOW:!EXP:!MD5:@STRENGTH"
--- Define path to server certificate with public key
config.serverCertificatePath = "./data/cert/spt_credential.pem"
--- Define path to server private key
config.serverPrivateKeyPath = "./data/cert/spt_credential.pem"
--- Define path to server CA certificates chain for client certificate validation
config.serverCAChainCertPath = "./data/cert/spt_credential.pem"
--- Define whether client certificate validation needed
config.isCheckClientCertificate = true

return config
