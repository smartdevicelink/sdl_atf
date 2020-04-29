--- Module which is responsible for creating ATF log during test script run
--
-- *Dependencies:* `json`, `atf.stdlib.std.io`, `protocol_handler.ford_protocol_constants`
--
-- *Globals:* `qdatetime`, `timestamp`, `config`
-- @module atf_logger
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local json = require('json')
local io = require('atf.stdlib.std.io')
local ford_constants = require("protocol_handler/ford_protocol_constants")

--- Singleton table which is used for perform all logging activities for ATF log.
-- @table Logger
-- @tfield boolean is_open Describe status of ATF log file
-- @tfield string full_atf_log_file Name of full ATF log file
-- @tfield string script_file_name Name of current script
-- @tfield string atf_log_file Name of normal ATF log file
-- @tfield number timestamp Current date + time (timestamp)
-- @tfield string mobile_log_format Format template for mobile communication log record
-- @tfield string hmi_log_format Format template for HMI communication log record
-- @tfield number start_file_timestamp Date + time (timestamp) of start to write log file
local Logger =
{
  is_open = true,
  full_atf_log_file = '',
  script_file_name = '',
  atf_log_file = '',
  timestamp = 0,
  mobile_log_format = '',
  hmi_log_format = '',
  start_file_timestamp = 0,
  mt = {
    __index = {}
  }
}

Logger.mobile_log_format = "%s [%s] [%s, sessionId: %s, version: %s, frameType: %s, "
      .. "encryption: %s, serviceType: %s, frameInfo: %s, messageId: %s, binaryDataSize: %s] : %s \n\n"
Logger.hmi_log_format = "%s [%s] %s \n"

local rpc_function_id
local ctrl_msg_map = (function()
    local out = {}
    for key, value in pairs(ford_constants.FRAME_INFO) do
      out[value] = key
    end
    return out
  end)()

--- Get function name from Mobile API
-- @tparam table message Message table
-- @treturn string Function name
local function get_function_name(message)
  local function getControlFrameMessageName(frameInfo)
    local name = ctrl_msg_map[frameInfo]
    if name ~= nil then return name end
    return string.format("UNKNOWN(0x%02x)", frameInfo)
  end

  if message.frameType ~= ford_constants.FRAME_TYPE.CONTROL_FRAME then
    if message.serviceType == ford_constants.SERVICE_TYPE.CONTROL
        and message.rpcType == ford_constants.BINARY_RPC_TYPE.NOTIFICATION
        and message.rpcFunctionId == ford_constants.BINARY_RPC_FUNCTION_ID.HANDSHAKE then
      return "SSL: Handshake"
    end
  else
    return "controlMsg: " .. getControlFrameMessageName(message.frameInfo)
  end

  for name, id in pairs(rpc_function_id) do
    if id == message.rpcFunctionId then
      return "rpcFunction: " .. name
    end
  end

  return "nil"
end

--- Create string representation of current time in set format
-- @tparam ?boolean without_date Set date format
--
-- true: "hh:mm:ss,zzz";
--
-- false or nil: "dd MM yyyy hh:mm:ss, zzz"
-- @treturn string Formated date representation
function Logger.formated_time(without_date)
  if without_date == true then
    return qdatetime.get_datetime("hh:mm:ss,zzz")
  end
  return qdatetime.get_datetime("dd-MM-yyyy hh:mm:ss,zzz")
end

--- Check message is it HMI tract
-- @treturn boolean Return true if tract is HMI tract
local function is_hmi_tract(tract, message)
  local str = string.format("%s", tract)
  if string.find(str, "HMI")
    or (message.frameType ~= ford_constants.FRAME_TYPE.CONTROL_FRAME)
    and (message.serviceType ~= ford_constants.SERVICE_TYPE.PCM)
    and (message.serviceType ~= ford_constants.SERVICE_TYPE.VIDEO) then
    return true
  end
  return false
end

--- Calculate binary data size
-- @tparam string binaryData Binary data of message
-- @treturn number Binary data size
local function getBinaryDataSize(binaryData)
  if binaryData then
    return #binaryData
  end
  return 0
end

--- Store message from mobile application to SDL into ATF log file
-- @tparam string tract Tract information
-- @tparam string message String representation of message from mobile application to SDL
function Logger:MOBtoSDL(tract, message)
  local log_str = string.format(Logger.mobile_log_format,"MOB->SDL", Logger.formated_time(),
    get_function_name(message), message.sessionId, message.version, message.frameType,
    message.encryption, message.serviceType, message.frameInfo, message.messageId, getBinaryDataSize(message.binaryData), message.payload)
  if is_hmi_tract(tract, message) then
    self.atf_log_file:write(log_str)
  end
  if config.storeFullATFLogs then
    self.full_atf_log_file:write(log_str)
  end
end

--- Store auxiliary message about start of new test step for test scenario into ATF log file
-- @tparam string test_case_name Test step name
function Logger:StartTestCase(test_case_name)
  self.atf_log_file:write(string.format("\n\n===== %s : \n", test_case_name))
  if config.storeFullATFLogs then
    self.full_atf_log_file:write(string.format("\n\n===== %s : \n", test_case_name))
  end
end

--- Store message from SDL to mobile application into ATF log file
-- @tparam string tract Tract information
-- @tparam string message String representation of message from SDL to mobile application
function Logger:SDLtoMOB(tract, message)
  local payload = message.payload
  if type(payload) == "table" then
    payload = json.encode(payload)
  end

  local log_str = string.format(Logger.mobile_log_format,"SDL->MOB", Logger.formated_time(),
    get_function_name(message), message.sessionId, message.version, message.frameType,
    message.encryption, message.serviceType, message.frameInfo, message.messageId, getBinaryDataSize(message.binaryData), payload)
  if is_hmi_tract(tract, message) then
    self.atf_log_file:write(log_str)
  end
  if config.storeFullATFLogs then
    self.full_atf_log_file:write(log_str)
  end
end

--- Store message from HMI to SDL into ATF log file
-- @tparam string tract Tract information
-- @tparam string message String representation of message from HMI to SDL
function Logger:HMItoSDL(tract, message)
  local log_str = string.format(Logger.hmi_log_format, "HMI->SDL", Logger.formated_time(), message .. "\n")
  if is_hmi_tract(tract, message) then
    self.atf_log_file:write(log_str)
  end
  if config.storeFullATFLogs then
    self.full_atf_log_file:write(log_str)
  end
end

--- Store message from SDL to HMI into ATF log file
-- @tparam string tract Tract information
-- @tparam string message String representation of message from SDL to HMI
function Logger:SDLtoHMI(tract, message)
  local log_str = string.format(Logger.hmi_log_format, "SDL->HMI", Logger.formated_time(), message)
  if is_hmi_tract(tract, message) then
    self.atf_log_file:write(log_str)
  end
  if config.storeFullATFLogs then
    self.full_atf_log_file:write(log_str)
  end
end

--- Build script name on basis of script file name
local function get_script_name(script_file_name)
  local tbl = table.pack(string.match(script_file_name, '(.-)([^/]-([^%.]+))$'))
  local name = tbl[#tbl-1]:gsub('%.'..tbl[#tbl]..'$', '')
  return name
end

--- Build log file name with full absolute path and create all folders on file system for it
local function get_log_file_name(timestamp, log_file_type)
  local dir_name = './' .. Logger.script_file_name
  local script_name = get_script_name(dir_name)
  if not timestamp then timestamp = tostring(os.date('%Y%m%d%H%M%S', os.time())) end
  if (config.reportPath == nil or config.reportPath == '') then
    config.reportPath = "."
  end
  local reportMark = config.reportMark
  if (reportMark == nil) then reportMark = ''
  else reportMark = "_" .. reportMark end
  local curr_log_dir = config.reportPath .. '/' .. log_file_type
  local curr_log_path = io.catdir(curr_log_dir ..'_'.. timestamp, io.catdir(io.dirname(dir_name)))
  local full_log_name = io.catfile(curr_log_path, script_name ..'_'..timestamp .. reportMark)
  os.execute('mkdir -p "'.. curr_log_path .. '"')
  return full_log_name
end

--- Initialization of ATF logger
-- @tparam string script_name Test script name
function Logger.init_log(script_name)
  rpc_function_id = require('function_id')
  Logger.script_file_name = script_name
  Logger.start_file_timestamp = timestamp()

  local timestamp = tostring(os.date('%Y%m%d%H%M%S', os.time()))
  local log_file_name = get_log_file_name(timestamp, "ATFLogs")
  local atf_log_file_name = log_file_name ..".txt"
  Logger.atf_log_file = io.open(atf_log_file_name, "r")
  if Logger.atf_log_file ~= nil then
    io.close(Logger.atf_log_file)
  end
  Logger.atf_log_file = io.open(atf_log_file_name, "w+")

  if config.storeFullATFLogs then
    local full_atf_log_file_name = log_file_name .. "_full.txt";
    Logger.full_atf_log_file = io.open(full_atf_log_file_name, "r")
    if Logger.full_atf_log_file ~= nil then
      io.close(Logger.full_atf_log_file)
    end
    Logger.full_atf_log_file = io.open(full_atf_log_file_name, "w+")
  end

  setmetatable(Logger, Logger.mt)
  Logger.is_open = true
  return Logger
end

--- Store auxiliary message about start of new test step of test scenario into ATF log file
-- @tparam string test_case Test step name
function Logger.LOGTestCaseStart(test_case)
  Logger:StartTestCase(test_case)
end

--- Store message on baasis on tract information into ATF log file
-- @tparam string tract Tract information
-- @tparam string message String representation of message
function Logger.LOG(tract, message)
  Logger[tract](Logger, tract, message)
end

--- Store auxiliary message about finish of test scenario into ATF log file
-- @tparam number count Test scenario executing time in seconds
function Logger.LOGTestFinish(count)
  Logger.atf_log_file:write(string.format("\n\n===== Total executing time is %s =====\n", count))
  if config.storeFullATFLogs then
    Logger.full_atf_log_file:write(string.format("\n\n===== Total executing time is %s =====\n", count))
  end
end

return Logger
