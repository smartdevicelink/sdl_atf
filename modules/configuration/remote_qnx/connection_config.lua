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
config.remoteConnection.enabled = true
--- Define host for default remote connection
config.remoteConnection.url = "172.16.141.128"
config.remoteConnection.port = 5555
config.hmiAdapterConfig = {}
config.hmiAdapterConfig.hmiAdapterType = "Remote"

--- Define host for default mobile device connection
config.mobileHost = "172.16.141.1"
--- Define port for default mobile device connection
config.mobilePort = 12345

--- Define host for SDL logs
config.sdl_logs_host = "172.16.141.128"
--- Define port for SDL logs
config.sdl_logs_port = 6676

return config
