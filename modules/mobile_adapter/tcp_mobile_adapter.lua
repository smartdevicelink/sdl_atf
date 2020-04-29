--- Module which provides transport level interface for emulate connection with mobile for SDL
--
-- *Dependencies:* `qt`, `network`
--
-- *Globals:* `xmlReporter`, `qt`, `network`
-- @module tcp_connection
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local Tcp = { mt = { __index = {} } }

--- Type which provides transport level interface for emulate connection with mobile for SDL
-- @type Connection

--- Construct instance of Connection type
-- @tparam string host SDL host address
-- @tparam string port SDL port
-- @treturn Connection Constructed instance
function Tcp.Connection(params)
  local res =
  {
    targetHost = params.host,
    targetPort = params.port,
    sourceHost = params.source
  }
  res.socket = network.TcpClient()
  setmetatable(res, Tcp.mt)
  res.qtproxy = qt.dynamic()

  function res:inputData() end

  function res.qtproxy.readyRead()
    while true do
      local data = res.socket:read(81920)
      if data == '' then break end
      res.qtproxy:inputData(data)
    end
  end
  qt.connect(res.socket, "readyRead()", res.qtproxy, "readyRead()")

  return res
end

--- Check 'self' argument
local function checkSelfArg(s)
  if type(s) ~= "table" or
  getmetatable(s) ~= Tcp.mt then
    error("Invalid argument 'self': must be connection (use ':', not '.')")
  end
end

--- Connect with SDL through QT transport interface
function Tcp.mt.__index:Connect()
  xmlReporter.AddMessage("tcp_connection","Connect")
  checkSelfArg(self)
  self.socket:connect(self.targetHost, self.targetPort, config.connectionTimeout, self.sourceHost)
end

--- Send pack of messages from mobile to SDL
-- @tparam table data Data to be sent
function Tcp.mt.__index:Send(data)
  -- xmlReporter.AddMessage("tcp_connection","Send", data)
  checkSelfArg(self)
  for _, c in ipairs(data) do
    self.socket:write(c)
  end
end

--- Set handler for OnInputData
-- @tparam function func Handler function
function Tcp.mt.__index:OnInputData(func)
  checkSelfArg(self)
  local d = qt.dynamic()
  local this = self
  function d:inputData(data)
    func(this, data)
  end
  qt.connect(self.qtproxy, "inputData(QByteArray)", d, "inputData(QByteArray)")
end

--- Set handler for OnDataSent
-- @tparam function func Handler function
function Tcp.mt.__index:OnDataSent(func)
  local d = qt.dynamic()
  local this = self
  function d:bytesWritten(num)
    func(this, num)
  end
  qt.connect(self.socket, "bytesWritten(qint64)", d, "bytesWritten(qint64)")
end

--- Set handler for OnConnected
-- @tparam function func Handler function
function Tcp.mt.__index:OnConnected(func)
  checkSelfArg(self)
  if self.qtproxy.connected then
    error("Tcp connection: connected signal is handled already")
  end
  local this = self
  self.qtproxy.connected = function() func(this) end
  qt.connect(self.socket, "connected()", self.qtproxy, "connected()")
end

--- Set handler for OnDisconnected
-- @tparam function func Handler function
function Tcp.mt.__index:OnDisconnected(func)
  checkSelfArg(self)
  if self.qtproxy.disconnected then
    error("Tcp connection: disconnected signal is handled already")
  end
  local this = self
  self.qtproxy.disconnected = function() func(this) end
  qt.connect(self.socket, "disconnected()", self.qtproxy, "disconnected()")
end

--- Close connection
function Tcp.mt.__index:Close()
  xmlReporter.AddMessage("tcp_connection","Close")
  checkSelfArg(self)
  self.socket:close();
end

return Tcp
