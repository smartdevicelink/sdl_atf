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

--- Define security protocol for WSS default mobile device connection
--  TlsV1_0 - TLS 1.0
--  TlsV1_1 - TLS 1.1
--  TlsV1_2 - TLS 1.2
--  DtlsV1_0 - DTLS 1.0
--  DtlsV1_2 - DTLS 1.2
--  TlsV1SslV3 - TLS 1.0 or SSL 3.0
config.wssSecurityProtocol = "TlsV1SslV3"
--- Define cypher list for WSS default mobile device connection
config.wssCypherListString = "ALL"
--- Define CA certificate for WSS default mobile device connection
config.wssCertificateCAPath = "./files/Security/WebEngine/ca-cert.pem"
--- Define client certificate for WSS default mobile device connection
config.wssCertificateClientPath = "./files/Security/WebEngine/client-cert.pem"
--- Define client private key for WSS default mobile device connection
config.wssPrivateKeyPath = "./files/Security/WebEngine/client-key.pem"

return config
