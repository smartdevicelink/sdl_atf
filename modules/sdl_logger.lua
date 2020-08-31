--- Module which is responsible for creating SDL logs during test scripts run
--
-- *Dependencies:* `atf.stdlib.std.io`
--
-- *Globals:* `network`, `qt`, `config`
-- @module sdl_logger
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local io = require('atf.stdlib.std.io')

--- Singleton table which is used for perform all logging activities for SDL log.
-- @table SdlLogger
-- @tfield boolean is_open Describe status of SDL log file
-- @tfield string full_sdlLog_name Name of full SDL log file
-- @tfield string script_file_name Name of current script
-- @tfield string sdl_log_file Name of normal SDL log file
-- @tfield number timestamp Current date + time (timestamp)
local SdlLogger = {
  is_open = true,
  full_sdlLog_name = '',
  script_file_name = '',
  sdl_log_file = '',
  timestamp = 0,
  mt = {
    __index={}
  }
}

--- Build script name from path to its file
-- @tparam string script_file_name Path to script file
-- @treturn string Script name
local function get_script_name(script_file_name)
  local tbl = table.pack(string.match(script_file_name, '(.-)([^/]-([^%.]+))$'))
  local name = tbl[#tbl-1]:gsub('%.'..tbl[#tbl]..'$', '')
  return name
end

--- Build SDL log path
-- @tparam number timestamp Date + time (timestamp)
-- @tparam string log_file_type Type of SDL log
-- @treturn string Path to SDL log
local function get_log_file_name(timestamp, log_file_type)
  local dir_name = './' .. SdlLogger.script_file_name
  local script_name = get_script_name(dir_name)
  if not timestamp then timestamp = tostring(os.date('%Y%m%d%H%M%S', os.time())) end
  SdlLogger.timestamp = timestamp
  if (config.reportPath == nil or config.reportPath == '') then
    config.reportPath = "."
  end
  local reportMark = config.reportMark
  if (reportMark == nil) then
    reportMark = ''
  else
    reportMark = "_" .. reportMark
  end

  local curr_log_dir = config.reportPath .. '/' .. log_file_type
  local curr_log_path = curr_log_dir ..'_'.. timestamp
  local full_log_name = io.catfile(curr_log_path, script_name ..'_'..timestamp .. reportMark)
  os.execute('mkdir -p "'.. curr_log_path .. '"')
  return full_log_name
end

--- Initialization of SDL logger
-- @tparam string host Host of SDL
-- @tparam string port Port of SDl
-- @treturn table SDL logger
local function init(host,port)
  local res =
  {
    host = host,
    port = port
  }
  SdlLogger.socket = network.TcpClient()
  if not SdlLogger.socket then
    print("TcpClient returns nothing")
    return nil
  end
  SdlLogger.sdl_log_file = io.open(SdlLogger.full_sdlLog_name,"r")
  if SdlLogger.sdl_log_file ~= nil then
    io.close(SdlLogger.sdl_log_file)
    print("sdl_logger: file already created")
  end
  SdlLogger.sdl_log_file = io.open(SdlLogger.full_sdlLog_name,"w+")
  res.qtproxy = qt.dynamic()
  setmetatable(res, SdlLogger.mt)
  return res
end

--- Creation and connection of  SDL logger
-- @tparam string script_name Test script name
function SdlLogger.init_log(script_name)
  SdlLogger.script_file_name = script_name
  local timestamp = tostring(os.date('%Y%m%d%H%M%S', os.time()))
  SdlLogger.full_sdlLog_name = get_log_file_name(timestamp, "SDLLogs")..".log"
  SdlLogger.Connect(init(config.sdl_logs_host, config.sdl_logs_port))
end

--- Write data received from SDL into SDL log
function SdlLogger.dataReady()
  local data = SdlLogger.socket:read_all()
  SdlLogger.sdl_log_file:write(data)
end

--- Connect SDL logger to SDL
function SdlLogger.Connect(self)
  self.qtproxy.dataReady = function() SdlLogger.dataReady() end
  qt.connect(SdlLogger.socket, "readyRead()", self.qtproxy, "dataReady()")
  SdlLogger.socket:connect(self.host, self.port, config.connectionTimeout)
end

--- Close SDL logger connection to SDL
function SdlLogger.close()
  if(SdlLogger.socket) then SdlLogger.socket:close() end
end

return SdlLogger
