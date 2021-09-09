--- Module which provides transport level interface for emulate connection to SDL from HMI for streaming
--
-- *Dependencies:* `qt`, `network`
--
-- *Globals:* `qt`, `network`
-- @module Stream
-- @copyright [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local ATF = require("ATF")

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

  local function flushStreamTcpData()
    local file = io.open("tcp_stream.out","w+b")
    local streamedData = table.concat(res.data)
    file:write(streamedData)
    file:close()
  end

  local function processInputData(data)
    local tableIndex = #res.data

    if tableIndex == 0 then
        -- trim off HTTP header
        local headerDelimeter = "\r\n\r\n"
        local headerSize = data:find(headerDelimeter) + headerDelimeter:len()
        data = string.sub(data, headerSize)
    end

    table.insert(res.data, data);
    res.receivedBytes = res.receivedBytes + data:len()

    if res.callbackBytes ~= -1 and res.receivedBytes >= res.callbackBytes then
      flushStreamTcpData()
      res.callback(true, res.callbackBytes, "tcp_stream.out")
      res.callbackBytes = -1
    end
  end

  function res.qtproxy.readyRead()
    while true do
      local data = res.socket:read(81920)
      if data == '' or type(data) ~= "string" then break end
      processInputData(data)
    end
  end

  res.qtproxy.disconnected = function()
    if res.receivedBytes < res.callbackBytes then
      flushStreamTcpData()
      res.callback(false, res.receivedBytes, "tcp_stream.out")
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
    local pipeContentFileName = "pipe_stream.out"
    local command = "head -c " .. tostring(bytes) .. " " .. pipe .. " > " .. pipeContentFileName
    if config.remoteConnection.enabled then
      ATF.remoteUtils.app:ExecuteCommand(command)
      local _, isExists = ATF.remoteUtils.file:IsFileExists(".", pipeContentFileName)
      if isExists then
        local isSuccess, path = ATF.remoteUtils.file:GetFile(".", pipeContentFileName)
        if isSuccess then
          ATF.remoteUtils.file:DeleteFile(".", pipeContentFileName)
          local file = io.open(path, "rb")
          res.receivedBytes = file:seek("end")
          file:close()
          pipeContentFileName = path
        else
          pipeContentFileName = ""
        end
      else
        pipeContentFileName = ""
      end
    else
      os.execute(command)
      local file = io.open(pipeContentFileName, "rb")
      res.receivedBytes = file:seek("end")
      file:close()
    end
    local success = res.receivedBytes >= res.callbackBytes
    res.callback(success, res.receivedBytes, pipeContentFileName)
    return res
  end

return Stream
