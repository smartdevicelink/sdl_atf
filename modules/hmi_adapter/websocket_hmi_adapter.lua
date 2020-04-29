--- Module which provides transport level interface for emulate connection with HMI for SDL
--
-- *Dependencies:* `json`, `qt`, `network`
--
-- *Globals:* `atf_logger`, `qt`, `network`
-- @module websocket_connection
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local json = require("json")

local WS = {
  mt = { __index = {} }
}

--- Type which provides transport level interface for emulate connection with HMI for SDL
-- @type WebSocketConnection

--- Construct instance of WebSocketConnection type
-- @tparam string url URL for websocket
-- @tparam number port Port for Websocket
-- @treturn WebSocketConnection Constructed instance
function WS.Connection(params)
  local res =
  {
    url = params.url,
    port = params.port
  }
  res.socket = network.WebSocket()
  setmetatable(res, WS.mt)
  res.qtproxy = qt.dynamic()
  return res
end

--- Connect with SDL
function WS.mt.__index:Connect()
  self.socket:open(self.url, self.port, config.connectionTimeout)
end

--- Check 'self' argument
local function checkSelfArg(s)
  if type(s) ~= "table" or
  getmetatable(s) ~= WS.mt then
    error("Invalid argument 'self': must be connection (use ':', not '.')")
  end
end

--- Send message from HMI to SDL
-- @tparam string text Message
function WS.mt.__index:Send(data)
  local text
  if type(data) == "table" then
    text = json.encode(data)
  else
    text = data
  end

  atf_logger.LOG("HMItoSDL", text)
  self.socket:write(text)
end

--- Set handler for OnInputData
-- @tparam function func Handler function
function WS.mt.__index:OnInputData(func)
  local d = qt.dynamic()
  local this = self
  function d:textMessageReceived(text)
    atf_logger.LOG("SDLtoHMI", text)
    local data = json.decode(text)
    --print("ws input:", text)
    func(this, data)
  end
  qt.connect(self.socket, "textMessageReceived(QString)", d, "textMessageReceived(QString)")
end

--- Set handler for OnDataSent
-- @tparam function func Handler function
function WS.mt.__index:OnDataSent(func)
  local d = qt.dynamic()
  local this = self
  function d:bytesWritten(num)
    func(this, num)
  end
  qt.connect(self.socket, "bytesWritten(qint64)", d, "bytesWritten(qint64)")
end

--- Set handler for OnConnected
-- @tparam function func Handler function
function WS.mt.__index:OnConnected(func)
  if self.qtproxy.connected then
    error("Websocket connection: connected signal is handled already")
  end
  local this = self
  self.qtproxy.connected = function() func(this) end
  qt.connect(self.socket, "connected()", self.qtproxy, "connected()")
end

--- Set handler for OnDisconnected
-- @tparam function func Handler function
function WS.mt.__index:OnDisconnected(func)
  if self.qtproxy.disconnected then
    error("Websocket connection: disconnected signal is handled already")
  end
  local this = self
  self.qtproxy.disconnected = function() func(this) end
  qt.connect(self.socket, "disconnected()", self.qtproxy, "disconnected()")
end

--- Close connection
function WS.mt.__index:Close()
  checkSelfArg(self)
  self.socket:close();
end

return WS
