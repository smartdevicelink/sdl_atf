--- Module which provides utils interface for application management on remote host
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @module RemoteAppUtils
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local constants = require("remote/remote_constants")

local RemoteAppUtils = {
	mt = { __index = {} }
}

local function HandleResult(result, data)
  local isResultValid = false
  for _, v in pairs(constants.ERROR_CODE) do
    if result == v then
      isResultValid = true
      break;
    end
  end

  if not isResultValid then
    error("Module RemoteAppUtils received invalid result value: " .. result)
  end

  if result == constants.ERROR_CODE.SUCCESS then
    if data == nil then
      return true
    else
      return true, data
    end
  end
  if data == nil then
    return false
  else
    return false, nil
  end
end

--- Module which provides utils interface for application management on remote host
-- @type RemoteAppUtils

--- Construct instance of RemoteAppUtils type
-- @tparam RemoteConnection connection RemoteConnection instance
-- @treturn RemoteAppUtils Constructed instance
function RemoteAppUtils.RemoteAppUtils(connection)
  local res = { }
  res.connection = connection:GetConnection()
  setmetatable(res, RemoteAppUtils.mt)
  return res
end

--- Check connection
-- @treturn boolean Return true in case connection is active
function RemoteAppUtils.mt.__index:Connected()
  return self.connection:connected()
end

--- Start application on remote host
-- @tparam string remotePathToApp Path to application file on remote host
-- @tparam string fileName Name of application executive file
-- @treturn boolean Return true in case of success
function RemoteAppUtils.mt.__index:StartApp(remotePathToApp, appName)
  return HandleResult(self.connection:app_start(remotePathToApp, appName))
end

--- Stop application on remote host
-- @tparam string remotePathToApp Path to application file on remote host
-- @tparam string fileName Name of application executive file
-- @treturn boolean Return true in case of success
function RemoteAppUtils.mt.__index:StopApp(appName)
  return HandleResult(self.connection:app_stop(appName))
end

--- Check status of application on remote host
-- @tparam string remotePathToApp Path to application file on remote host
-- @tparam string fileName Name of application executive file
-- @treturn boolean Return true in case of success
-- @treturn number Return status of application
function RemoteAppUtils.mt.__index:CheckAppStatus(appName)
  return HandleResult(self.connection:app_check_status(appName))
end

--- Command_execute run bush command on remote host
-- @tparam string bash_command command for exucute on remote host
-- @treturn output for this command
function RemoteAppUtils.mt.__index:ExecuteCommand(bash_command)
  return HandleResult(self.connection:command_execute(bash_command))
end

return RemoteAppUtils
