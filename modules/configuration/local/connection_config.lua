--- Module which provides ATF connection configuration
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local config = { }

--- Remote cofiguration
config.remoteConnection = {}
config.remoteConnection.enabled = false

config.hmiAdapterConfig = {}
config.hmiAdapterConfig.hmiAdapterType = "WebSocket"

--- Default mobile connection
--
--- Define transport type for default mobile device connection
-- TCP - TCP connection (connection parameters: mobileHost, mobilePort)
-- WS - WebSocket connection (connection parameters: wsMobileURL, wsMobilePort)
-- WSS - WebSocketSecure connection (connection parameters: wssMobileURL, wssMobilePort,
--      wssCertificateCA, wssCertificateClient, wssPrivateKey)
config.defaultMobileAdapterType = "TCP"
--- Define host for TCP default mobile device connection
config.mobileHost = "127.0.0.1"
--- Define port for TCP default mobile device connection
config.mobilePort = 12345
--

--- Define host for SDL logs
config.sdl_logs_host = "127.0.0.1"
--- Define port for SDL logs
config.sdl_logs_port = 6676

return config
