--- Module which provides utils interface for file management on remote host
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @module remote.remote_file_utils
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local constants = require("remote/remote_constants")

local RemoteFileUtils = {
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
    error("Module RemoteFileUtils received invalid result value: " .. result)
  end
  if isResultBoolean == true then
    return isSuccess, isSuccess
  end
  return isSuccess, data
end

--- Module which provides utils interface for file management on remote host
-- @type RemoteFileUtils

--- Construct instance of RemoteFileUtils type
-- @tparam RemoteConnection connection RemoteConnection instance
-- @treturn RemoteFileUtils Constructed instance
function RemoteFileUtils.RemoteFileUtils(connection)
  local res = { }
  res.connection = connection:GetConnection()
  setmetatable(res, RemoteFileUtils.mt)
  return res
end

--- Check connection
-- @treturn boolean Return true in case connection is active
function RemoteFileUtils.mt.__index:Connected()
  return self.connection:connected()
end

--- Check file existance on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
-- @treturn boolean Return true in case of file exists
function RemoteFileUtils.mt.__index:IsFileExists(remotePathToFile, fileName)
  local rpcName = "file_exists"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFile
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileName
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Create new file with content on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @tparam string fileContent Content of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:CreateFile(remotePathToFile, fileName, fileContent)
  local result, isExists = self:IsFileExists(remotePathToFile, fileName)
  if not result or (result and isExists) then
    return false
  end
  return self:UpdateFileContent(remotePathToFile, fileName, fileContent)
end

--- Delete file on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:DeleteFile(remotePathToFile, fileName)
  local rpcName = "file_delete"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFile
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileName
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Backup file on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:BackupFile(remotePathToFile, fileName)
  local rpcName = "file_backup"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFile
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileName
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Restore backuped file on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:RestoreFile(remotePathToFile, fileName)
  local rpcName = "file_restore"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFile
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileName
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Update file with content on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @tparam string fileContent Content of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:UpdateFileContent(remotePathToFile, fileName, fileContent)
  local rpcName = "file_update"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFile
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileName
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileContent
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Get file content from remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
-- @treturn string Path to file with content of remote file
function RemoteFileUtils.mt.__index:GetFile(remotePathToFile, fileName)
  local rpcName = "file_content"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFile
    },
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = fileName
    }
  }
  return HandleResult(false, self.connection:file_call(rpcName, parameters))
end

--- Check folder existance on remote host
-- @tparam string remotePathToFolder Path to folder on remote host
-- @treturn boolean Return true in case of success
-- @treturn boolean Return true in case of folder exists
function RemoteFileUtils.mt.__index:IsFolderExists(remotePathToFolder)
  local rpcName = "folder_exists"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFolder
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Create folder on remote host
-- @tparam string remotePathToFolder Path to folder on remote host
-- @tparam string folderName Name of folder
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:CreateFolder(remotePathToFolder)
  local rpcName = "folder_create"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFolder
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

--- Delete folder on remote host
-- @tparam string remotePathToFolder Path to folder on remote host
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:DeleteFolder(remotePathToFolder)
  local rpcName = "folder_delete"
  local parameters = {
    {
      type = constants.PARAMETER_TYPE.STRING,
      value = remotePathToFolder
    }
  }
  return HandleResult(true, self.connection:call(rpcName, parameters))
end

return RemoteFileUtils
