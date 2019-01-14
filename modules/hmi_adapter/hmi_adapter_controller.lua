--- Module which provides HMI Adapter control functionality on base of ATF configuration
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @module HmiAdapterController
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local HmiAdapterController = {}

local hmiAdapter
if config.hmiAdapterConfig.hmiAdapterType == "Remote" then
  hmiAdapter = require('hmi_adapter/remote_hmi_adapter')
elseif config.hmiAdapterConfig.hmiAdapterType == "WebSocket" then
  hmiAdapter = require('hmi_adapter/websocket_hmi_adapter')
else
  error("Invalid value '".. config.hmiAdapterConfig.hmiAdapterType
    .." for configuration parameter 'config.hmiAdapterConfig.hmiAdapterType'")
end

--- Provide HMI adapter instance on base of ATF configuration
-- @tparam table params Specific parameters for HDMI adapter
-- @treturn table HMI adapter instance
function HmiAdapterController.getHmiAdapter(params)
  if config.hmiAdapterConfig.hmiAdapterType == "Remote" and
      not config.remoteConnection.enabled then
    error("Remote HMI adapter can not be instantiated: Remote connection disabled in config")
  end
  local hmiAdapterParams = config.hmiAdapterConfig[config.hmiAdapterConfig.hmiAdapterType]
  for param, value in pairs(params) do
    if hmiAdapterParams[param] then
      print("Config HMI adapter parameter '" .. param
          .. "' was overwritten with '" .. value .. "' value")
    end
    hmiAdapterParams[param] = value
  end

  return hmiAdapter.Connection(hmiAdapterParams)
end

return HmiAdapterController
