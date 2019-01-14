---- Provides high level interface for test script creation
--
-- *Dependencies:* `remote.remote_connection`, `remote.remote_file_utils`, `remote.remote_application_utils`
--
-- *Globals:* `config`
-- @module ATF
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local remote_connection = require("remote/remote_connection")
local remote_file_utils = require("remote/remote_file_utils")
local remote_application_utils = require("remote/remote_application_utils")

--- Type ATF provides high level interface for test script creation
-- @type ATF

ATF = {}

if config.remoteConnection.enabled then
  ATF.remoteConnection = remote_connection.RemoteConnection(config.remoteConnection.url, config.remoteConnection.port)
  ATF.remoteConnection:Connect()
  ATF.remoteUtils = {}
  ATF.remoteUtils.file = remote_file_utils.RemoteFileUtils(ATF.remoteConnection)
  ATF.remoteUtils.app = remote_application_utils.RemoteAppUtils(ATF.remoteConnection)
end

return ATF
