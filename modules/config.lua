--- Module which provides ATF configuration and predefined mobile application data
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local config = { }
--- Flag which defines usage of color for reporting
config.color = true
--- Define URL for HMI connection
config.hmiUrl = "ws://localhost"
--- Define port for HMI connection
config.hmiPort = 8087
--- Default mobile connection
--
--- Define transport type for default mobile device connection
-- TCP - TCP connection (connection parameters: mobileHost, mobilePort)
-- WS - WebSocket connection (connection parameters: wsMobileURL, wsMobilePort)
-- WSS - WebSocketSecure connection (connection parameters: wssMobileURL, wssMobilePort,
--      wssCertificateCA, wssCertificateClient, wssPrivateKey)
config.defaultMobileAdapterType = "TCP"
--- Define host for TCP default mobile device connection
config.mobileHost = "localhost"
--- Define port for TCP default mobile device connection
config.mobilePort = 12345
--- Define URL for WS default mobile device connection
config.wsMobileURL = "ws://localhost"
--- Define port for WS default mobile device connection
config.wsMobilePort = 2020
--- Define URL for WSS default mobile device connection
config.wssMobileURL = "wss://localhost"
--- Define port for WSS default mobile device connection
config.wssMobilePort = 2020
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
config.wssCertificateCAPath = "./data/cert/wss/ca-cert.pem"
--- Define client certificate for WSS default mobile device connection
config.wssCertificateClientPath = "./data/cert/wss/client-cert.pem"
--- Define client private key for WSS default mobile device connection
config.wssPrivateKeyPath = "./data/cert/wss/client-key.pem"
--
--- Define timeout for Heartbeat in msec
config.heartbeatTimeout = 7000
--- Define timeout to wait for the events that should not occur
config.zeroOccurrenceTimeout = 2000
--- Flag which defines whether ATF checks all validations for particular expectation or just till the first which fails
config.checkAllValidations = false
--- Define default version of Ford protocol
-- 1 - basic
--
-- 2 - RPC, encryption
--
-- 3 - video/audio streaming, heartbeat
-- 4 - SDL 4.0
config.defaultProtocolVersion = 3
--- Define path to SDL binary
-- Example: "/home/user/sdl_build/bin"
config.pathToSDL = ""
--- Define path to SDL interfaces
-- Example: "/home/user/sdl_panasonic/src/components/interfaces"
config.pathToSDLInterfaces = ""
--- Define SDL modification
config.SDL = "smartDeviceLinkCore"
--- Definehost for SDL logs
config.sdl_logs_host = "localhost"
--- Define port for SDL logs
config.sdl_logs_port = 6676
--- Flag which defines behavior of ATF on SDL crash
config.ExitOnCrash = true
--- Flag which defines whether ATF starts SDL on startup
config.autorunSDL = true
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
--- Logs and Reports
--
--- Flag which defines whether ATF displays time of test step run
config.ShowTimeInConsole = true
--- Flag which defines whether ATF performs validation of Mobile and HMI messages by API
config.ValidateSchema = true
--- Flag which defines whether ATF ignores collecting of reports
config.excludeReport = true
--- Flag which defines whether ATF creates full ATF logs (with json files and service messages)
config.storeFullATFLogs = true
--- Flag which defines whether ATF stores full SDLCore logs
config.storeFullSDLLogs = true
--- Define path to collected ATF and SDL logs
config.reportPath = "./TestingReports"
--- Define delays for storing sdl log -"x" before start script
-- and +"x" after end script execution. In milliseconds(ms).
config.x_sdllog = 100

--- Predefined mobile application data (application1)
config.application1 =
{
  registerAppInterfaceParams =
  {
    syncMsgVersion =
    {
      majorVersion = 6,
      minorVersion = 0
    },
    appName = "Test Application",
    isMediaApplication = true,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0001",
    fullAppID = "0000001",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

--- Predefined mobile application data (application2)
config.application2 =
{
  registerAppInterfaceParams =
  {
    syncMsgVersion =
    {
      majorVersion = 6,
      minorVersion = 0
    },
    appName = "Test Application2",
    isMediaApplication = true,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0002",
    fullAppID = "0000002",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

--- Predefined mobile application data (application3)
config.application3 =
{
  registerAppInterfaceParams =
  {
    syncMsgVersion =
    {
      majorVersion = 6,
      minorVersion = 0
    },
    appName = "Test Application3",
    isMediaApplication = true,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0003",
    fullAppID = "0000003",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

--- Predefined mobile application data (application4)
config.application4 =
{
  registerAppInterfaceParams =
  {
    syncMsgVersion =
    {
      majorVersion = 6,
      minorVersion = 0
    },
    appName = "Test Application4",
    isMediaApplication = true,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0004",
    fullAppID = "0000004",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

--- Predefined mobile application data (application5)
config.application5 =
{
  registerAppInterfaceParams =
  {
    syncMsgVersion =
    {
      majorVersion = 6,
      minorVersion = 0
    },
    appName = "Test Application5",
    isMediaApplication = true,
    languageDesired = 'EN-US',
    hmiDisplayLanguageDesired = 'EN-US',
    appHMIType = { "NAVIGATION" },
    appID = "0005",
    fullAppID = "0000005",
    deviceInfo =
    {
      os = "Android",
      carrier = "Megafon",
      firmwareRev = "Name: Linux, Version: 3.4.0-perf",
      osVersion = "4.4.2",
      maxNumberRFCOMMPorts = 1
    }
  }
}

return config
