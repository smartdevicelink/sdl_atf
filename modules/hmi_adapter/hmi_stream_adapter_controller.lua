--- Module which provides transport level interface for emulate connection to SDL from HMI for streaming
--
-- *Dependencies:* `qt`, `network`
--
-- *Globals:* `qt`, `network`
-- @module Stream
-- @copyright [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local Stream = { }

--- Type which provides transport level interface for emulate connection with SDL from HMI
-- @type Connection

--- Construct instance of Connection type
-- @tparam string host SDL host address
-- @tparam number port SDL port
-- @tparam number bytes Number of bytes to receive before calling callback
-- @tparam function func Callback when stream ends or number of bytes are received
-- @treturn Connection Constructed instance
function Stream.TcpConnection(host, port, bytes, func)
  local res =
  {
    host = host,
    port = port,
    callback = func,
    callbackBytes = bytes,
    receivedBytes = 0,
    data = {}
  }

  res.socket = network.TcpClient()
  res.qtproxy = qt.dynamic()

  local function streamTcpCleanup()
    local file = io.open("tcp_stream.out","w+b")
    local streamedData = table.concat(res.data)
    file:write(streamedData)
    file:close()
  end

  function res.qtproxy.inputData(_, data)
    local tableIndex = #res.data

    if tableIndex == 0 then
        -- trim off HTTP header
        local headerEnd = data:find("\r\n\r\n")
        data = string.sub(data, headerEnd + 4)
    end

    table.insert(res.data, data);
    local data_len = #data
    res.receivedBytes = res.receivedBytes + data_len

    if res.callbackBytes ~= -1 and res.receivedBytes >= res.callbackBytes then
      streamTcpCleanup()
      res.callback(true, res.callbackBytes, "tcp_stream.out")
      res.callbackBytes = -1
    end
  end

  function res.qtproxy.readyRead()
    while true do
      local data = res.socket:read(81920)
      if data == '' or type(data) ~= "string" then break end
      res.qtproxy:inputData(data)
    end
  end

  res.qtproxy.disconnected = function()
    if res.receivedBytes < res.callbackBytes then
      streamTcpCleanup()
      res.callback(false, res.receivedBytes, "tcp_video.out")
    end
  end

  qt.connect(res.socket, "disconnected()", res.qtproxy, "disconnected()")

  res.qtproxy.connected = function() print("HMI connected to stream") end
  qt.connect(res.socket, "connected()", res.qtproxy, "connected()")

  qt.connect(res.socket, "readyRead()", res.qtproxy, "readyRead()")
  res.socket:connect(host, port, config.connectionTimeout)

  return res
end

--- Construct instance of Connection type
-- @tparam string pipe Path to pipe of data
-- @tparam number bytes Number of bytes to receive before calling callback
-- @tparam function func Callback when stream ends or number of bytes are received
-- @treturn Connection Constructed instance
function Stream.PipeConnection(pipe, bytes, func)
    local res =
    {
      callback = func,
      callbackBytes = bytes,
      receivedBytes = 0,
    }

    os.execute("head -c " .. tostring(bytes) .. " " .. pipe .. " > pipe_stream.out")
    local file = io.open("pipe_stream.out", "rb")
    res.receivedBytes = file:seek("end")
    file:close()

    local success = res.receivedBytes >= res.callbackBytes
    res.callback(success, res.receivedBytes, "pipe_stream.out")

    return res
  end

return Stream
