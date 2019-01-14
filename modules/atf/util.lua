--[[-- ATF common utils

  Utils component is a set of classes for ATF components support

  For component overview description and a list of responsibilities, please, follow [ATF SAD Component View](https://smartdevicelink.com/en/guides/pull_request/93dee199f30303b4b26ec9a852c1f5261ff0735d/atf/components-view/#utils).

  *Dependencies:* `atf.stdlib.argument_parser`, `config`, `reporter`, `atf_logger`

  *Globals:* `config`, `xmlReporter`, `atf_logger`, `table2str()`, `print_table()`, `is_file_exists()`, `compareValues()`, `print_usage()`
  @module atf.util
  @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
  @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>
]]
local utils = require("atf.stdlib.argument_parser")
config = require('config')
xmlReporter = require("reporter")
atf_logger = require("atf_logger")

--- Singleton table which is used for perform script run and command line activities for ATF .
-- @table Util
-- @tfield table commandLine Table that used for perform command line activities in ATF
-- @tfield table runner Table that used for perform script run activities in ATF
local Util = {
  commandLine = {},
  runner = {
    script_file_name = ""
  }
}

Util.commandLine.consts = {
  RequiredArgument = utils.RequiredArgument,
  OptionalArgument = utils.OptionalArgument,
  NoArgument = utils.NoArgument
}

--- Convert milliseconds count to string in a format
-- "1d 2h 3m 4s 5ms (summary 999ms)".
-- @param milliseconds
-- @return result string in a format
local function convert_ms(milliseconds)
  local seconds = math.floor( (milliseconds / 1000) % 60)
  local minutes = math.floor( ((milliseconds / (1000 * 60)) % 60))
  local hours = math.floor(((milliseconds / (1000 * 60 * 60)) % 24))
  local days = math.floor( (milliseconds / (1000 * 60 * 60 * 24)))
  local ms = milliseconds - (days*(1000 * 60 * 60 * 24)+ hours*(1000 * 60 * 60)+minutes*(1000 * 60)+seconds*1000)
  local converted_time = "(summary ".. tostring(milliseconds).. "ms)"
  if ms ~= 0 then
    converted_time = tostring(ms).."ms "..converted_time
  end
  if seconds ~= 0 then
    converted_time = tostring(seconds).."s "..converted_time
  end
  if minutes ~= 0 then
    converted_time = tostring(minutes).."min "..converted_time
  end
  if hours ~=0 then
    converted_time = tostring(hours).."h "..converted_time
  end
  if days ~=0 then
    converted_time = tostring(days).."d "..converted_time
  end
  return converted_time
end

--- Check mandatory files existence for testing
-- Checks: SDL Core binary, HMI and MObile API files
-- Stop ATF execution in case any error
local function check_required_fields()
  if not config.remoteConnection.enabled then
    if (not is_file_exists(config.pathToSDL..config.SDL)) and
       (not is_file_exists(config.pathToSDL.."/" .. config.SDL)) then
      print("ERROR: SDL is not accessible at the specified path: "..config.pathToSDL)
      os.exit(1)
    end
  end
  if config.pathToSDLInterfaces~="" and config.pathToSDLInterfaces~=nil then
    if (not is_file_exists(config.pathToSDLInterfaces.."MOBILE_API.xml")) and
       (not is_file_exists(config.pathToSDLInterfaces.."/MOBILE_API.xml")) then
      print("ERROR: XML files are not accessible at the specified path: "..config.pathToSDLInterfaces)
      os.exit(1)
    end
  else
    print "\27[33m WARNING: Parameter pathToSDLInterfaces is not specified, default APIs are used \27[0m"
  end
end

--- Serialization any lua table to string
-- @param o table for converting to string
function table2str(o)
  if type(o) == 'table' then
    local s = '{ '
    for k,v in pairs(o) do
      if type(k) ~= 'number' then k = '"'..k..'"' end
      s = s .. '['..k..'] = ' .. table2str(v) .. ','
    end
    return s .. '} \n'
  end
  return tostring(o)
end

--- Print lua tables to console
-- @param t list of tables
function print_table(t,... )
  if (type(t) == 'table' ) then
    print(table2str(t).. table2str(table.pack(...)))
  else
    print(tostring(t).. table2str(table.pack(...)))
  end
end

--- Check file exist ans by given path
-- @param name absolute path to the file
-- @return boll existence
function is_file_exists(name)
  local f = io.open(name,"r")
  if f ~=nil then io.close(f) return true else return false end
end

--- Remove table filed by name and value
-- @param t table for manipulation
-- @param k key value for remove
-- @return result table
function table.removeKey(t, k)
  local i = 0
  local keys, values = {},{}
  for k,v in pairs(t) do
    i = i + 1
    keys[i] = k
    values[i] = v
  end

  while i>0 do
    if keys[i] == k then
        table.remove(keys, i)
        table.remove(values, i)
    break
    end
    i = i - 1
  end

  local a = {}
    for i = 1,#keys do
        a[keys[i]] = values[i]
    end
  return a
end

--- Compare 2 tables field by field
-- @param a first table
-- @param b second table
-- @param name table help comment for output error string
-- @return results bool value of comparison and error message
function compareValues(a, b, name)
  local function iter(a, b, name, msg)
    if type(a) == 'table' and type(b) == 'table' then
      local res = true
      if #a ~= #b then
        table.insert(msg, string.format("number of array elements %s: expected %s, actual: %s", name, #a, #b))
        res = false
      end
      for k, v in pairs(a) do
        res = res and iter(v, b[k], name .. "." .. k, msg)
      end
      return res
    else
      if (type(a) ~= type(b)) then
        if (type(a) == 'string' and type(b) == 'number') then
          b = tostring(b)
        else
          table.insert(msg, string.format("type of data %s: expected %s, actual type: %s", name, type(a), type(b)))
          return false
        end
      end
      if a == b then
        return true
      else
        table.insert(msg, string.format("%s: expected: %s, actual value: %s", name, a, b))
        return false
      end
    end
  end
  local message = { }
  local res = iter(a, b, name, message)
  return res, table.concat(message, '\n')
end

--- Print usage
function print_usage()
  utils.PrintUsage()
end
-- ------------------------------------------------
-- parsing command line part

--- Set config file for ATF
-- @tparam string config_file Path to config file
function Util.commandLine.config_file(config_file)
  if (is_file_exists(config_file)) then
    config_file = config_file:gsub('%.', " ")
    config_file = config_file:gsub("/", ".")
    config_file = config_file:gsub("[%s]lua$", "")
    config = require(tostring(config_file))
  else
    print("Incorrect config file type")
    print("Uses default config")
    print("==========================")
  end
end

--- Overwrite property mobileHost in configuration of ATF
-- @tparam string str Value
function Util.commandLine.mobile_connection(str)
  config.mobileHost = str
end

--- Overwrite property mobilePort in configuration of ATF
-- @tparam string src Value
function Util.commandLine.mobile_connection_port(src)
  config.mobilePort = src
end

--- Overwrite property hmiUrl in configuration of ATF
-- @tparam string str Value
function Util.commandLine.hmi_connection(str)
  config.hmiUrl = str
end

--- Overwrite property hmiPort in configuration of ATF
-- @tparam string src Value
function Util.commandLine.hmi_connection_port(src)
  config.hmiPort = src
end

--- Overwrite property perflogConnection in configuration of ATF
-- @tparam string str Value
function Util.commandLine.perflog_connection(str)
  config.perflogConnection = str
end

--- Overwrite property perflogConnectionPort in configuration of ATF
-- @tparam string str Value
function Util.commandLine.perflog_connection_port(str)
  config.perflogConnectionPort = str
end

--- Overwrite property reportPath in configuration of ATF
-- @tparam string str Value
function Util.commandLine.report_path(str)
  config.reportPath = str
end

--- Overwrite property reportMark in configuration of ATF
-- @tparam string str Value
function Util.commandLine.report_mark(str)
  config.reportMark = str
end

--- Overwrite property storeFullSDLLogs in configuration of ATF
-- @tparam string str Value
function Util.commandLine.storeFullSDLLogs(str)
  config.storeFullSDLLogs = str
end

--- Overwrite property heartbeatTimeout in configuration of ATF
-- @tparam string str Value
function Util.commandLine.heartbeat(str)
  config.heartbeatTimeout = str
end

--- Overwrite property pathToSDL in configuration of ATF
-- @tparam string str Value
function Util.commandLine.sdl_core(str)
  config.pathToSDL = str
end

--- Overwrite property pathToSDLInterfaces in configuration of ATF
-- @tparam string str Value
function Util.commandLine.sdl_interfaces(str)
  config.pathToSDLInterfaces = str
end

--- Overwrite property pathToSDL in configuration of ATF
-- @tparam string str Value
function Util.commandLine.security_protocol(str)
  config.SecurityProtocol = str
end

--- Parse command line string
-- @treturn table Script files list
function Util.commandLine.parse_cmdl()
  local scriptFiles = {}
  local arguments = utils.getopt(argv, opts)
  if (arguments) then
    if (arguments['config-file']) then Util.commandLine.config_file(arguments['config-file']) end
    for argument, value in pairs(arguments) do
      if (type(argument) ~= 'number') then
        if ( argument ~= 'config-file') then
          argument = (argument):gsub ("%W", "_")
          Util.commandLine[argument](value)
        end
      else
        if argument >= 2 and value ~= "modules/launch.lua" then
          table.insert(scriptFiles, value)
        end
      end
    end
  end
  return scriptFiles
end

--- Declare command line option with both names (-n, --name)
-- @tparam table ... Option declaration table
function Util.commandLine.declare_opt(...)
  utils.declare_opt(...)
end

--- Declare command line option with only long name (--name)
-- @tparam table ... Option declaration table
function Util.commandLine.declare_long_opt(...)
  utils.declare_long_opt(...)
end

--- Declare command line option with only short name (-n)
-- @tparam table ... Option declaration table
function Util.commandLine.declare_short_opt(...)
  utils.declare_short_opt(...)
end

local function copy_file(file, newfile)
  return os.execute(string.format('cp "%s" "%s"', file, newfile))
end

local function copy_interfaces()
  if config.pathToSDLInterfaces ~= "" and config.pathToSDLInterfaces ~= nil then
    local mobile_api = config.pathToSDLInterfaces .. '/MOBILE_API.xml'
    local hmi_api = config.pathToSDLInterfaces .. '/HMI_API.xml'
    copy_file(mobile_api, 'data/MOBILE_API.xml')
    copy_file(hmi_api, 'data/HMI_API.xml')
  end
end

--- Runner

--- Function for receive current script file name
-- @treturn string Script file name
function Util.runner.get_script_file_name()
  return Util.runner.script_file_name
end

--- Print script information before run of script
-- @tparam string script_name Name of script to print
function Util.runner.print_startscript(script_name)
  print("==============================")
  print(string.format("Start '%s'",script_name))
  print("==============================")
end

--- Print script result information after run of script
-- @tparam string script_name Name of script to print
function Util.runner.print_stopscript(script_name)
  local count =  timestamp() - atf_logger.start_file_timestamp
  local counttime =  convert_ms(count)
  atf_logger.LOGTestFinish(counttime)
  print(string.format("Total executing time is %s", counttime))
  print("==============================")
  print(string.format("Finish '%s'",script_name or Util.runner.script_file_name))
  print("==============================")
end

--- Test script execution
-- @param script_name path to the script file with a tests
function Util.runner.script_execute(script_name)
  check_required_fields()
  copy_interfaces()
  Util.runner.script_file_name = script_name
  xmlReporter = xmlReporter.init(tostring(script_name))
  atf_logger = atf_logger.init_log(tostring(script_name))
  dofile(script_name)
end

return Util
