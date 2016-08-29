local json = require("json")
local Logger = {}
Logger.mobile_log_format = "%s(%s) [version: %s, frameType: %s, encryption: %s, serviceType: %s, frameInfo: %s, messageId: %s] : %s \n"
Logger.hmi_log_format = "%s[%s] : %s \n"


function capture_cmd_output(cmd, is_raw)
  local f = assert(io.popen(cmd, 'r'))
  local s = assert(f:read('*a'))
  f:close()
  if is_raw then return s end
  s = string.gsub(s, '^%s+', '')
  s = string.gsub(s, '%s+$', '')
  s = string.gsub(s, '[\n\r]+', ' ')
  return s
end

function split(inputstr, sep)
  if not sep then
    sep = "%s"
  end
  local t = {} ; i = 0
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    t[i] = str
    i = i + 1
  end
  return t
end

function formated_time()
  local time = capture_cmd_output("date +'%d %b %Y %T,%N'", false)
  time = split(time, ",")
  time[1] =  string.format("%03.0f", math.floor(tonumber(time[1]) / 1000000))
  return time[0]..','..time[1]
end

function Logger:MOBtoSDL(message)
  local log_str = string.format(Logger.mobile_log_format,"MOB->SDL ", formated_time(), message.version, message.frameType, message.encryption, message.serviceType, message.frameInfo, message.messageId, message.payload)
  self.atf_log_file:write(log_str)
end

function Logger:StartTestCase(test_case_name)
    self.atf_log_file:write(string.format("\n\n===== %s : \n", test_case_name))
end

function Logger:SDLtoMOB(message)
  local payload = message.payload
  if type(payload) == "table" then
    payload = json.encode(payload)
  end
  local log_str = string.format(Logger.mobile_log_format,"SDL->MOB", formated_time(), message.version, message.frameType, message.encryption, message.serviceType, message.frameInfo, message.messageId, payload)
  self.atf_log_file:write(log_str)
end

function Logger:HMItoSDL(message)
  local log_str = string.format(Logger.hmi_log_format, "HMI->SDL", formated_time(), message)
  self.atf_log_file:write(log_str)
end

function Logger:SDLtoHMI(message)
  local log_str = string.format(Logger.hmi_log_format, "SDL->HMI", formated_time(), message)
  self.atf_log_file:write(log_str)
end

function Logger:New(path_to_log_file)
  local logger = { mt = { __index = Logger}}
  logger.path_to_log_file = path_to_log_file
  logger.atf_log_file = io.open(path_to_log_file, "w+")
  setmetatable(logger, logger.mt)
  return logger
end

return Logger
