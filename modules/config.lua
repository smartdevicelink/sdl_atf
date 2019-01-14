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

--- Remote cofiguration
config.remoteConnection = {}
config.remoteConnection.enabled = true
--- Define host for default remote connection
config.remoteConnection.url = "127.0.0.1"
config.remoteConnection.port = 5555

--- HMI configuration
config.hmiAdapterConfig = {}
config.hmiAdapterConfig.hmiAdapterType = "Remote"
--- Define configuration parameters for HMI connection on WebSocket base
config.hmiAdapterConfig.WebSocket = {}
config.hmiAdapterConfig.WebSocket.url = "ws://localhost"
config.hmiAdapterConfig.WebSocket.port = 8087
--- Define configuration parameters for Remote HMI connection
config.hmiAdapterConfig.Remote = {}
--- Define configuration parameters for HMI connection on WebSocket base
-- for Remote HMI connection
config.hmiAdapterConfig.Remote.WebSocketConfig = {}
config.hmiAdapterConfig.Remote.WebSocketConfig.host = "127.0.0.1"
config.hmiAdapterConfig.Remote.WebSocketConfig.port = 8087


--- Define host for default mobile device connection
config.mobileHost = "127.0.0.1"
--- Define port for default mobile device connection
config.mobilePort = 12345
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
--- Define path to SDL .INI file
config.pathToSDLConfig = ""
--- Define path to SDL Policy database
config.pathToSDLPolicyDB = ""
--- Define path to SDL interfaces
-- Example: "/home/user/sdl_panasonic/src/components/interfaces"
config.pathToSDLInterfaces = ""
--- Define SDL modification
config.SDL = "smartDeviceLinkCore"
--- Define host for SDL logs
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
config.excludeReport = false
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
      majorVersion = 5,
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
      majorVersion = 5,
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
      majorVersion = 5,
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
      majorVersion = 5,
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
      majorVersion = 5,
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
