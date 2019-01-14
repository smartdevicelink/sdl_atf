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

local function HandleResult(result, data)
  local isResultValid = false
  for _, v in pairs(constants.ERROR_CODE) do
    if result == v then
      isResultValid = true
      break;
    end
  end

  if not isResultValid then
    error("Module RemoteFileUtils received invalid result value: " .. result)
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
  return HandleResult(self.connection:file_exists(remotePathToFile, fileName))
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
  return HandleResult(self.connection:file_delete(remotePathToFile, fileName))
end

--- Backup file on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:BackupFile(remotePathToFile, fileName)
  return HandleResult(self.connection:file_backup(remotePathToFile, fileName))
end

--- Restore backuped file on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:RestoreFile(remotePathToFile, fileName)
  return HandleResult(self.connection:file_restore(remotePathToFile, fileName))
end

--- Update file with content on remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @tparam string fileContent Content of file
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:UpdateFileContent(remotePathToFile, fileName, fileContent)
  return HandleResult(self.connection:file_update(remotePathToFile, fileName, fileContent))
end

--- Get file content from remote host
-- @tparam string remotePathToFile Path to file on remote host
-- @tparam string fileName Name of file
-- @treturn boolean Return true in case of success
-- @treturn string Path to file with content of remote file
function RemoteFileUtils.mt.__index:GetFile(remotePathToFile, fileName)
  return HandleResult(self.connection:file_content(remotePathToFile, fileName))
end

--- Check folder existance on remote host
-- @tparam string remotePathToFolder Path to folder on remote host
-- @treturn boolean Return true in case of success
-- @treturn boolean Return true in case of folder exists
function RemoteFileUtils.mt.__index:IsFolderExists(remotePathToFolder)
  return HandleResult(self.connection:folder_exists(remotePathToFolder))
end

--- Create folder on remote host
-- @tparam string remotePathToFolder Path to folder on remote host
-- @tparam string folderName Name of folder
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:CreateFolder(remotePathToFolder)
  return HandleResult(self.connection:folder_create(remotePathToFolder))
end

--- Delete folder on remote host
-- @tparam string remotePathToFolder Path to folder on remote host
-- @treturn boolean Return true in case of success
function RemoteFileUtils.mt.__index:DeleteFolder(remotePathToFolder)
  return HandleResult(self.connection:folder_delete(remotePathToFolder))
end

return RemoteFileUtils
