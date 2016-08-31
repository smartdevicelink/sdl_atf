local json = require("json")
local Logger = {}

Logger.mobile_log_format = "%s(%s) [version: %s, frameType: %s, encryption: %s, serviceType: %s, frameInfo: %s, messageId: %s] : %s \n"
Logger.hmi_log_format = "%s[%s] : %s \n"

function formated_time()
  return qdatetime.get_datetime("dd MM yyyy hh:mm:ss,zzz")
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
