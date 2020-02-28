--- Module which provides transport level interface for emulate web engine WS connection to SDL
--
-- *Dependencies:* `qt`, `network`
--
-- *Globals:* `xmlReporter`, `qt`, `network`
-- @module WebEngine
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local WebEngineWS = { mt = { __index = {} } }

--- Type which provides transport level interface for emulate connection with mobile for SDL
-- @type Connection

local ProtocolType = {
  TlsV1_0 = 2,
  TlsV1_1 = 3,
  TlsV1_2 = 4,
  DtlsV1_0 = 11,
  DtlsV1_2 = 13,
  TlsV1SslV3 = 6
}

--- Construct instance of Connection type
-- @tparam string host SDL host address
-- @tparam string port SDL port
-- @treturn Connection Constructed instance
function WebEngineWS.Connection(params)
  local res = {
    url = params.url,
    port = params.port,
    ssl = params.sslProtocol and {} or nil
  }

  if res.ssl then
    if not ProtocolType[params.sslProtocol] then
      error("Protocol " .. params.sslProtocol .. "is not supported")
    end
    res.ssl.protocol = ProtocolType[params.sslProtocol]
    res.ssl.cypherListString = params.sslCypherListString
    res.ssl.caCertPath = params.sslCaCertPath
    res.ssl.certPath = params.sslCertPath
    res.ssl.keyPath = params.sslKeyPath
  end

  res.socket = network.WebSocket()
  setmetatable(res, WebEngineWS.mt)
  res.qtproxy = qt.dynamic()

  return res
end

--- Check 'self' argument
local function checkSelfArg(s)
  if type(s) ~= "table" or
  getmetatable(s) ~= WebEngineWS.mt then
    error("Invalid argument 'self': must be connection (use ':', not '.')")
  end
end

--- Connect to SDL through QT transport interface
function WebEngineWS.mt.__index:Connect()
  xmlReporter.AddMessage("websocket_connection","Connect")
  checkSelfArg(self)
  -- function self.qtproxy:onSslErrors()
  --   print("SSL errors have occurred")
  -- end
  -- qt.connect(self.socket, "sslErrors(QList<QSslError>)", self.qtproxy, "onSslErrors(QList<QSslError>)")
  self.socket:open(self.url, self.port, config.connectionTimeout, self.ssl)
end

--- Send pack of messages from mobile to SDL
-- @tparam table data Data to be sent
function WebEngineWS.mt.__index:Send(data)
  checkSelfArg(self)
  for _, c in ipairs(data) do
    self.socket:binary_write(c)
  end
end

--- Set handler for OnInputData
-- @tparam function func Handler function
function WebEngineWS.mt.__index:OnInputData(func)
  local this = self
  function self.qtproxy:binaryMessageReceived(data)
    func(this, data)
  end
  qt.connect(self.socket, "binaryMessageReceived(QByteArray)", self.qtproxy, "binaryMessageReceived(QByteArray)")
end

--- Set handler for OnDataSent
-- @tparam function func Handler function
function WebEngineWS.mt.__index:OnDataSent(func)
  local this = self
  function self.qtproxy:bytesWritten(num)
    func(this, num)
  end
  qt.connect(self.socket, "bytesWritten(qint64)", self.qtproxy, "bytesWritten(qint64)")
end

--- Set handler for OnConnected
-- @tparam function func Handler function
function WebEngineWS.mt.__index:OnConnected(func)
  if self.qtproxy.connected then
    error("WebEngineWS connection: connected signal is handled already")
  end
  local this = self
  self.qtproxy.connected = function() func(this) end
  qt.connect(self.socket, "connected()", self.qtproxy, "connected()")
end

--- Set handler for OnDisconnected
-- @tparam function func Handler function
function WebEngineWS.mt.__index:OnDisconnected(func)
  if self.qtproxy.disconnected then
    error("WebEngineWS connection: disconnected signal is handled already")
  end
  local this = self
  self.qtproxy.disconnected = function() func(this) end
  qt.connect(self.socket, "disconnected()", self.qtproxy, "disconnected()")
end

--- Close connection
function WebEngineWS.mt.__index:Close()
  checkSelfArg(self)
  xmlReporter.AddMessage("websocket_connection", "Close")
  self.socket:close();
end

return WebEngineWS
