--- Module which provides transport level interface for remote connection
--
-- *Dependencies:* `remote`
--
-- *Globals:* none
-- @module RemoteConnection
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local remote = require("remote")
local RemoteConnection = {
  mt = { __index = {} }
}

--- Type which provides transport level interface for remote connection
-- @type RemoteConnection

--- Construct instance of RemoteConnection type
-- @tparam string url URL for RemoteConnection
-- @tparam number port Port for RemoteConnection
-- @treturn RemoteConnection Constructed instance
function RemoteConnection.RemoteConnection(url, port)
  local res = {
      url = url,
      port = port,
      connection = nil
  }
  setmetatable(res, RemoteConnection.mt)
  return res
end

--- Connect with Remote server
function RemoteConnection.mt.__index:Connect()
  self.connection = remote:RemoteClient(self.url, self.port)
  if not self.connection then
    error("RemoteConnection was not established.")
  end
end

--- Provide underlying connection
-- @treturn userdata Underlying connection instance
function RemoteConnection.mt.__index:GetConnection()
  return self.connection
end

--- Close connection
function RemoteConnection.mt.__index:Close()
  self.connection = nil
end

return RemoteConnection
