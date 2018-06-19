--- Module which provides middle level interface for emulate connection with mobile for SDL
--
-- *Dependencies:* `message_dispatcher`
--
-- *Globals:* none
-- @module file_connection
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local message_dispatcher = require("message_dispatcher")
local FileConnection = { mt = { __index = { } } }

--- Type which provides middle level interface for emulate connection with mobile for SDL
-- @type FileConnection

--- Construct instance of FileConnection type
-- @tparam string filename Name of file
-- @tparam TcpConnection connection Lower level connection
-- @treturn FileConnection Constructed instance
function FileConnection.FileConnection(filename, connection)
  local res = {}
  res.filename = filename
  res.connection = connection
  res.fbuf = message_dispatcher.FileStorage(filename)
  res.fmapper = message_dispatcher.MessageDispatcher(connection)
  res.fmapper:MapFile(res.fbuf)
  res.mapped = { }
  setmetatable(res, FileConnection.mt)
  return res
end

--- Connect with SDL
function FileConnection.mt.__index:Connect()
  self.connection:Connect()
end

--- Split message to chanks and send them to SDL
-- @tparam table data List of messages to be sent
function FileConnection.mt.__index:Send(data)
  for _, chunk in ipairs(data) do
    self.fbuf:WriteMessage(chunk)
  end
  self.fbuf:Flush()
  self.fmapper:Pulse()
end

--- Start streaming file to SDL
-- @tparam number session Session identificator
-- @tparam number version SDL protocol version
-- @tparam number service Sevice number
-- @tparam boolean encryption True in case of encrypted streaming
-- @tparam string filename Name of file to be streamed
-- @tparam number bandwidth Bandwidth in bytes
function FileConnection.mt.__index:StartStreaming(session, version, service, encryption, filename, bandwidth)
  local stream = message_dispatcher.FileStream(filename, version, session, service, encryption, bandwidth)
  self.mapped[filename] = stream
  self.fmapper:MapFile(stream)
  self.fmapper:Pulse()
end

--- Stop streaming file to SDL
-- @tparam string filename Name of file to be streamed
function FileConnection.mt.__index:StopStreaming(filename)
  if not self.mapped[filename] then
    error("Wrong ATF usage. You are trying to stop stream file \"" .. filename .. "\" which isn't being streamed right now")
  end
  self.fmapper:UnmapFile(self.mapped[filename])
  self.mapped[filename] = nil
end

--- Set handler for OnInputData
-- @tparam function func Handler function
function FileConnection.mt.__index:OnInputData(func)
  self.connection:OnInputData(func)
end

--- Set handler for OnDataSent
-- @tparam function func Handler function
function FileConnection.mt.__index:OnDataSent(func)
  self.connection:OnDataSent(func)
end

--- Set handler for OnMessageSent
-- @tparam function func Handler function
function FileConnection.mt.__index:OnMessageSent(func)
  self.fmapper:OnMessageSent(func)
end

--- Set handler for OnConnected
-- @tparam function func Handler function
function FileConnection.mt.__index:OnConnected(func)
  self.connection:OnConnected(func)
end

--- Set handler for OnDisconnected
-- @tparam function func Handler function
function FileConnection.mt.__index:OnDisconnected(func)
  self.connection:OnDisconnected(func)
end

--- Close connection
function FileConnection.mt.__index:Close()
  self.connection:Close()
  if self.fd then io.close(self.fd) end
end

return FileConnection
