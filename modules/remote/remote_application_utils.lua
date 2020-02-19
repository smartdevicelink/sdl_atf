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

local function HandleResult(isResultBoolean, result, data)
  local isResultValid = false
  local isSuccess
  if result == constants.ERROR_CODE.SUCCESS then
    isResultValid = true
    isSuccess = true
  else
    isSuccess = false
    for _, v in pairs(constants.ERROR_CODE) do
      if result == v then
        isResultValid = true
        break;
      end
    end
  end

  if not isResultValid then
    error("Module RemoteAppUtils received invalid result value: " .. result)
  end
  if isResultBoolean == true then
    return isSuccess, isSuccess
  end
  return isSuccess, data
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
-- @tparam string appName Name of application executive file
-- @treturn boolean Return true in case of success
function RemoteAppUtils.mt.__index:StartApp(remotePathToApp, appName)
  local rpcName = "app_start"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToApp
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = appName
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Stop application on remote host
-- @tparam string appName Name of application  on remote host
-- @treturn boolean Return true in case of success
function RemoteAppUtils.mt.__index:StopApp(appName)
  local rpcName = "app_stop"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = appName
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Check status of application on remote host
-- @tparam string appName Name of application  on remote host
-- @treturn boolean Return true in case of success
-- @treturn number Return status of application
function RemoteAppUtils.mt.__index:CheckAppStatus(appName)
  local rpcName = "app_check_status"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = appName
    }
  }
  return HandleResult(false, self.connection:call(rpcName, parameters))
end

--- Command_execute run bush command on remote host
-- @tparam string bashCommand command for exucute on remote host
-- @treturn output for this command
function RemoteAppUtils.mt.__index:ExecuteCommand(bashCommand)
  local rpcName = "command_execute"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = bashCommand
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

return RemoteAppUtils
