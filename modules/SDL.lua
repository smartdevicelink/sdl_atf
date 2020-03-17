--- The module which is responsible for managing SDL from ATF
--
-- *Dependencies:* `os`, `sdl_logger`, `atf.util`, `ATF`
--
-- *Globals:* `sleep()`, `CopyFile()`, `CopyInterface()`, `xmlReporter`, `console`, `config`
-- @module SDL
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('os')
local sdl_logger = require('sdl_logger')
local console = require('console')
local util = require ("atf.util")
local remote_constants = require('modules/remote/remote_constants')
local ATF = require("ATF")
local json = require("modules/json")

--[[ Module ]]
local SDL = { }

--- Table of SDL build options
SDL.buildOptions = {}
--- The flag responsible for stopping ATF in case of emergency completion of SDL
SDL.exitOnCrash = true
--- SDL state constant: SDL completed correctly
SDL.STOPPED = 0
--- SDL state constant: SDL works
SDL.RUNNING = 1
--- SDL state constant: SDL crashed
SDL.CRASH = -1
--- SDL state constant: SDL in idle mode (for remote only)
SDL.IDLE = -2

--[[ Local Functions ]]
local function getPath(pPath, pParentPath)
  if pParentPath == nil then pParentPath = config.pathToSDL end
  pParentPath = SDL.addSlashToPath(pParentPath)
  if string.len(pPath) > 0 then
    if string.sub(pPath, 1, 1) == "/" then
      return SDL.addSlashToPath(pPath)
    elseif string.len(pPath) == 1 and string.sub(pPath, 1, 1) == "." then
      return pParentPath
    else
      return SDL.addSlashToPath(pParentPath .. pPath)
    end
  end
  return pParentPath
end

local function getFilePath(pFilePath, pParentPath)
  if pParentPath == nil then pParentPath = config.pathToSDL end
  pParentPath = getPath(pParentPath)
  if string.len(pFilePath) > 0 then
    if string.sub(pFilePath, 1, 1) == "/" then
      return pFilePath
    end
      return pParentPath .. pFilePath
  end
  return nil
end

local function getExecFunc()
  if config.remoteConnection.enabled then
    return function(...) ATF.remoteUtils.app:ExecuteCommand(...) end
  end
  return os.execute
end

--- Update SDL logger config in order SDL will be able to write logs through Telnet
local function updateSDLLogProperties()
  if config.storeFullSDLLogs == true then
    local name = "log4j.rootLogger"
    local curValue = SDL.LOGGER.get(name)
    local newValue = "TelnetLogging"
    if not string.find(curValue, newValue) then
      SDL.LOGGER.set(name, curValue .. ", " .. newValue)
    end
    name = "log4j.appender.TelnetLogging.layout.ConversionPattern"
    curValue = SDL.LOGGER.get(name)
    if string.sub(curValue, -1) == "n" then
      SDL.LOGGER.set(name, string.sub(curValue, 1, -3))
    end

    local paramsToUpdate = {
      {
        name = "log4j.appender.TransportManagerLogFile",
        value = "SafeFileAppender\nlog4j.appender.TransportManagerLogFile.Threshold=OFF"
      },
      {
        name = "log4j.appender.ProtocolFordHandlingLogFile",
        value = "SafeFileAppender\nlog4j.appender.ProtocolFordHandlingLogFile.Threshold=OFF"
      }
    }
    for _, item in pairs(paramsToUpdate) do
      SDL.LOGGER.set(item.name, item.value)
    end
  end
end

--- Update paths to SDL and its config
local function updateSdlPaths()
  config.pathToSDL = SDL.addSlashToPath(config.pathToSDL)
  config.pathToSDLConfig = SDL.addSlashToPath(config.pathToSDLConfig)
end

local function getPathAndName(pPathToFile)
  local pos = string.find(pPathToFile, "/[^/]*$")
  local path = string.sub(pPathToFile, 1, pos)
  local name = string.sub(pPathToFile, pos + 1)
  return path, name
end

local function getFileContent(pPathToFile)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pPathToFile)
    local _, isExist = ATF.remoteUtils.file:IsFileExists(p, n)
    if isExist then
      local isSuccess, path = ATF.remoteUtils.file:GetFile(p, n)
      if isSuccess then
        pPathToFile = path
      else
        return nil
      end
    else
      return nil
    end
  end
  local file = io.open(pPathToFile, "r")
  local content = nil
  if file then
    content = file:read("*all")
    file:close()
    if config.remoteConnection.enabled then
      os.execute("rm -f " .. pPathToFile)
    end
  end
  return content
end

local function saveFileContent(pPathToFile, pContent)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pPathToFile)
    ATF.remoteUtils.file:UpdateFileContent(p, n, pContent)
  else
    local file = io.open(pPathToFile, "w")
    if file then
      file:write(pContent)
      file:close()
    end
  end
end

local function deleteFile(pPathToFile)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pPathToFile)
    ATF.remoteUtils.file:DeleteFile(p, n)
  else
    os.execute("rm -f " .. pPathToFile)
  end
end

local function deleteFolder(pPathToFolder)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pPathToFolder)
    ATF.remoteUtils.file:DeleteFolder(p, n)
  else
    os.execute("rm -rf " .. pPathToFolder)
  end
end

local function getParamValue(pContent, pParam)
  for line in pContent:gmatch("[^\r\n]+") do
    if string.match(line, "^%s*" .. pParam .. "%s*=%s*") ~= nil then
      if string.find(line, "%s*=%s*$") ~= nil then
        return ""
      end
      local b, e = string.find(line, "%s*=%s*.")
      if b ~= nil then
        return string.sub(line, e, string.len(line))
      end
    end
  end
end

local function setParamValue(pContent, pParam, pValue)
  pValue = string.gsub(pValue, "%%", "%%%%")
  local out = ""
  local find = false
  for line in pContent:gmatch("([^\r\n]*)[\r\n]") do
    local ptrn = "^%s*;*%s*".. pParam .. "%s*=.*"
    if string.find(line, ptrn) then
      if not find then
        if pValue == ";" then
          line = string.gsub(line, ptrn, pValue .. pParam .. " = ")
        else
          line = string.gsub(line, ptrn, pParam .. " = " .. tostring(pValue))
        end
        find = true
      else
        line  = ";" .. line
      end
    end
    out = out .. line .. "\n"
  end
  return out
end

local function isFileExist(pFile)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pFile)
    local _, isExist = ATF.remoteUtils.file:IsFileExists(p, n)
    return isExist
  else
    local file = io.open(pFile, "r")
    if file == nil then
      return false
    else
      file:close()
      return true
    end
  end
end

local function restore(pFilePath)
  local isExists = isFileExist(pFilePath .. "_origin")
  if isExists then
    if config.remoteConnection.enabled then
      local p, n = getPathAndName(pFilePath)
      ATF.remoteUtils.file:RestoreFile(p, n)
    else
      os.execute("cp " .. pFilePath .. "_origin " .. pFilePath)
      os.execute("rm -f " .. pFilePath .. "_origin")
    end
  end
end

local function backup(pFilePath)
  restore(pFilePath)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pFilePath)
    ATF.remoteUtils.file:BackupFile(p, n)
  else
    os.execute("cp " .. pFilePath .. " " .. pFilePath .. "_origin")
  end
end

--- Structure of SDL build options what to be set
local function getDefaultBuildOptions()
  local options = { }
  options.remoteControl = { sdlBuildParameter = "REMOTE_CONTROL", defaultValue = "ON" }
  options.extendedPolicy = { sdlBuildParameter = "EXTENDED_POLICY", defaultValue = "PROPRIETARY" }
  options.webSocketServerSupport =  { sdlBuildParameter = "BUILD_WEBSOCKET_SERVER_SUPPORT", defaultValue = "OFF" }
  return options
end

--- Set SDL build option as values of SDL module property
-- @tparam string optionName Build option to set value
-- @tparam string sdlBuildParam SDL build parameter to read value
-- @tparam string defaultValue Default value of set option
local function setSdlBuildOption(optionName, sdlBuildParam, defaultValue)
  local value, paramType = SDL.BuildOptions.get(sdlBuildParam)
  if value == nil then
    value = defaultValue
    local msg = "SDL build option " ..
      sdlBuildParam .. " is unavailable.\nAssume that SDL was built with " ..
      sdlBuildParam .. " = " .. defaultValue
    print(console.setattr(msg, "cyan", 1))
  else
    if paramType == "UNINITIALIZED" then
      value = nil
      local msg = "SDL build option " ..
        sdlBuildParam .. " is unsupported."
      print(console.setattr(msg, "cyan", 1))
    end
  end
  SDL.buildOptions[optionName] = value
end

--- Set all SDL build options for SDL module of ATF
-- @tparam table self Reference to SDL module
local function setAllSdlBuildOptions()
  for option, data in pairs(getDefaultBuildOptions()) do
    setSdlBuildOption(option, data.sdlBuildParameter, data.defaultValue)
  end
end

function SDL.addSlashToPath(pPath)
  if pPath == nil or string.len(pPath) == 0 then return end
  if pPath:sub(-1) ~= '/' then
    pPath = pPath .. "/"
  end
  return pPath
end

SDL.BuildOptions = {}

function SDL.BuildOptions.file()
  return config.pathToSDL .. "build_config.txt"
end

function SDL.BuildOptions.get(pParam)
  local content = getFileContent(SDL.BuildOptions.file())
  if content then
    for line in content:gmatch("[^\r\n]+") do
      local pType, pValue = string.match(line, "^%s*" .. pParam .. ":(.+)=(%S*)")
      if pValue then
        return pValue, pType
      end
    end
  end
  return nil
end

function SDL.BuildOptions.set()
  -- Useless for now
end

SDL.INI = {}

function SDL.INI.file()
  local path = config.pathToSDLConfig
  if path == nil or path == "" then
    path = config.pathToSDL
  end
  return path .. "smartDeviceLink.ini"
end

function SDL.INI.get(pParam)
  local content = getFileContent(SDL.INI.file())
  return getParamValue(content, pParam)
end

function SDL.INI.set(pParam, pValue)
  local content = getFileContent(SDL.INI.file())
  content = setParamValue(content, pParam, pValue)
  saveFileContent(SDL.INI.file(), content)
end

function SDL.INI.backup()
  backup(SDL.INI.file())
end

function SDL.INI.restore()
  restore(SDL.INI.file())
end

SDL.LOGGER = {}

function SDL.LOGGER.file()
  return config.pathToSDL .. "log4cxx.properties"
end

function SDL.LOGGER.get(pParam)
  local content = getFileContent(SDL.LOGGER.file())
  return getParamValue(content, pParam)
end

function SDL.LOGGER.set(pParam, pValue)
  local content = getFileContent(SDL.LOGGER.file())
  content = setParamValue(content, pParam, pValue)
  saveFileContent(SDL.LOGGER.file(), content)
end

function SDL.LOGGER.backup()
  backup(SDL.LOGGER.file())
end

function SDL.LOGGER.restore()
  restore(SDL.LOGGER.file())
end

SDL.PreloadedPT = {}

function SDL.PreloadedPT.file()
  return getFilePath(SDL.INI.get("PreloadedPT"), SDL.INI.get("AppConfigFolder"))
end

function SDL.PreloadedPT.get()
  local content = getFileContent(SDL.PreloadedPT.file())
  return json.decode(content)
end

function SDL.PreloadedPT.set(pPPT)
  local content = json.encode(pPPT)
  saveFileContent(SDL.PreloadedPT.file(), content)
end

function SDL.PreloadedPT.backup()
  backup(SDL.PreloadedPT.file())
end

function SDL.PreloadedPT.restore()
  restore(SDL.PreloadedPT.file())
end

SDL.CRT = {}

function SDL.CRT.get()
end

function SDL.CRT.set(pCrtsFileName, pIsModuleCrtDefined)
  local ext = ".crt"

  local function getAllCrtsFromPEM(pPemFileName)

    local function readFile(pPath)
      local open = io.open
      local file = open(pPath, "rb")
      if not file then return nil end
      local content = file:read "*a"
      file:close()
      return content
    end

    local crts = readFile(pPemFileName)
    local o = {}
    local i = 1
    local s = crts:find("-----BEGIN RSA PRIVATE KEY-----", i, true)
    local _, e = crts:find("-----END RSA PRIVATE KEY-----", i, true)
    o.key = crts:sub(s, e) .. "\n"
    for _, v in pairs({ "crt", "rootCA", "issuingCA" }) do
      i = e
      s = crts:find("-----BEGIN CERTIFICATE-----", i, true)
      _, e = crts:find("-----END CERTIFICATE-----", i, true)
      o[v] = crts:sub(s, e) .. "\n"
    end
    return o
  end

  local function createCrtHash(pCrtFilePath)
    local p, n = getPathAndName(pCrtFilePath)
    getExecFunc()("cd " .. p
      .. " && openssl x509 -in " .. n
      .. " -hash -noout | awk '{print $0\".0\"}' | xargs ln -sf " .. n)
  end

  if pIsModuleCrtDefined == nil then pIsModuleCrtDefined = true end
  local allCrts = getAllCrtsFromPEM(pCrtsFileName)
  local crtPath = getPath(SDL.INI.get("CACertificatePath"))
  for _, v in pairs({ "rootCA", "issuingCA" }) do
    saveFileContent(crtPath .. v .. ext, allCrts[v])
    createCrtHash(crtPath .. v .. ext)
  end
  if pIsModuleCrtDefined then
    saveFileContent(crtPath .. "module_key" .. ext, allCrts.key)
    saveFileContent(crtPath .. "module_crt" .. ext, allCrts.crt)
  end
  SDL.INI.set("KeyPath", crtPath .. "module_key" .. ext)
  SDL.INI.set("CertificatePath", crtPath .. "module_crt" .. ext)
end

function SDL.CRT.clean()
  local ext = ".crt"
  local crtPath = getPath(SDL.INI.get("CACertificatePath"))
  getExecFunc()("cd " .. crtPath .. " && find . -type l -not -name 'lib*' -exec rm -f {} \\;")
  getExecFunc()("cd " .. crtPath .. " && rm -rf *" .. ext)
end

SDL.PTS = {}

function SDL.PTS.file()
  return getFilePath(SDL.INI.get("PathToSnapshot"), SDL.INI.get("SystemFilesPath"))
end

function SDL.PTS.get()
  local content = getFileContent(SDL.PTS.file())
  if content ~= nil then
    return json.decode(content)
  end
  return nil
end

function SDL.PTS.clean()
  deleteFile(SDL.PTS.file())
end

SDL.HMICap = {}

function SDL.HMICap.file()
  return getFilePath(SDL.INI.get("HMICapabilities"), SDL.INI.get("AppConfigFolder"))
end

function SDL.HMICap.get()
  local content = getFileContent(SDL.HMICap.file())
  return json.decode(content)
end

function SDL.HMICap.set(pHMICap)
  local content = json.encode(pHMICap)
  saveFileContent(SDL.HMICap.file(), content)
end

function SDL.HMICap.backup()
  backup(SDL.HMICap.file())
end

function SDL.HMICap.restore()
  restore(SDL.HMICap.file())
end

SDL.PolicyDB = {}

function SDL.PolicyDB.clean()
  deleteFile(getFilePath(config.pathToSDLPolicyDB, SDL.INI.get("AppStorageFolder")))
end

SDL.Log = {}

function SDL.Log.path()
  return config.pathToSDL
end

function SDL.Log.clean()
  getExecFunc()("rm -rf " .. SDL.Log.path() .. "*.log")
end

SDL.AppStorage = {}

function SDL.AppStorage.path()
  return getPath(SDL.INI.get("AppStorageFolder"))
end

function SDL.AppStorage.isFileExist(pFile)
  pFile = SDL.AppStorage.path() .. pFile
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pFile)
    local _, isExist = ATF.remoteUtils.file:IsFileExists(p, n)
    return isExist
  else
    local file = io.open(pFile, "r")
    if file == nil then
      return false
    else
      file:close()
      return true
    end
  end
end

function SDL.AppStorage.clean(pPath)
  if pPath == nil then
    pPath = "*"
  end
  getExecFunc()("rm -rf " .. SDL.AppStorage.path() .. pPath)
end

SDL.AppInfo = {}

function SDL.AppInfo.file()
  return getFilePath(SDL.INI.get("AppInfoStorage"))
end

function SDL.AppInfo.get()
  local content = getFileContent(SDL.AppInfo.file())
  if content ~= nil then return json.decode(content) end
  return {}
end

function SDL.AppInfo.set(pAppInfo)
  local content = json.encode(pAppInfo)
  saveFileContent(SDL.AppInfo.file(), content)
end

function SDL.AppInfo.backup()
  backup(SDL.AppInfo.file())
end

function SDL.AppInfo.restore()
  restore(SDL.AppInfo.file())
end

function SDL.AppInfo.clean()
  deleteFile(SDL.AppInfo.file())
end

--- A global function for organizing execution delays (using the OS)
-- @tparam number n The delay in ms
function sleep(n)
  os.execute("sleep " .. tonumber(n))
end

--- Launch SDL from ATF
-- @tparam string pathToSDL Path to SDL
-- @tparam string smartDeviceLinkCore The name of the SDL to run
-- @tparam boolean ExitOnCrash Flag whether Stop ATF in case SDL shutdown
-- @treturn boolean The main result. Indicates whether the launch of SDL was successful
-- @treturn string Additional information on the main SDL startup result
function SDL:StartSDL(pathToSDL, smartDeviceLinkCore, ExitOnCrash, isAppInfoUpdate)
  if isAppInfoUpdate == nil then isAppInfoUpdate = true end
  local result
  if ExitOnCrash ~= nil then
    self.exitOnCrash = ExitOnCrash
  end
  local status = self:CheckStatusSDL()

  if (status == self.RUNNING) then
    local msg = "SDL had already started out of ATF"
    xmlReporter.AddMessage("StartSDL", {["message"] = msg})
    print(console.setattr(msg, "cyan", 1))
    return false, msg
  end

  if isAppInfoUpdate then
    local appInfoTable = {
      Languages = { TTS = 0, UI = 0, VR = 0 },
      TransportManager = {
        BluetoothAdapter = json.null,
        TcpAdapter = json.null,
        WebsocketServerAdapter = {
          device = { unique_id = config.webengineUniqueId }
        }
      },
      remoteControl = json.EMPTY_OBJECT,
      resumption = {
        global_ign_on_counter = 0,
        resume_app_list = json.EMPTY_ARRAY
      }
    }
    if not SDL.AppInfo.get().resumption then SDL.AppInfo.set(appInfoTable) end
  end

  if config.remoteConnection.enabled then
     result = ATF.remoteUtils.app:StartApp(pathToSDL, smartDeviceLinkCore)
  else
     result = os.execute('./tools/StartSDL.sh ' .. pathToSDL .. ' ' .. smartDeviceLinkCore)
  end

  local msg
  if result then
    msg = "SDL started"
    if config.storeFullSDLLogs == true then
      sdl_logger.init_log(util.runner.get_script_file_name())
    end
  else
    msg = "SDL had already started not from ATF or unexpectedly crashed"
    print(console.setattr(msg, "cyan", 1))
  end
  xmlReporter.AddMessage("StartSDL", {["message"] = msg})
  return result, msg
end

--- Stop SDL from ATF (SIGINT is used)
-- @treturn nil The main result. Always nil.
-- @treturn string Additional information on the main result of stopping SDL
function SDL:StopSDL()
  self.autoStarted = false
  local status = self:CheckStatusSDL()
  if status == self.RUNNING or status == self.IDLE then
    if config.remoteConnection.enabled then
      ATF.remoteUtils.app:StopApp(config.SDL)
    else
      os.execute('./tools/StopSDL.sh')
    end
  else
    local msg = "SDL had already stopped"
    xmlReporter.AddMessage("StopSDL", {["message"] = msg})
    print(console.setattr(msg, "cyan", 1))
  end
  if config.storeFullSDLLogs == true then
    sdl_logger.close()
  end
  sleep(1)
end

function SDL.ForceStopSDL()
  if config.remoteConnection.enabled then
    ATF.remoteUtils.app:StopApp(config.SDL)
  else
    os.execute("ps aux | grep ./" .. config.SDL .. " | awk '{print $2}' | xargs kill -9")
  end
  sleep(1)
end

function SDL.WaitForSDLStart(test)
  local expectations = require('expectations')
  local events = require('events')
  local step = 100
  local event = events.Event()
  event.matches = function(e1, e2) return e1 == e2 end
  local function raise_event()
    local output
    if config.remoteConnection.enabled then
      local res, state = ATF.remoteUtils.app:CheckAppStatus(config.SDL)
      if not res then
        error("RemoteUtils.app unable to get status of application: " .. config.SDL)
      end
      output = (state == remote_constants.APPLICATION_STATUS.RUNNING)
    else
      local hmiPort = config.hmiAdapterConfig.WebSocket.port
      output = os.execute("netstat -vatn  | grep " .. hmiPort .. " | grep LISTEN")
    end
    if output then
      RAISE_EVENT(event, event)
    else
      RUN_AFTER(raise_event, step)
    end
  end
  RUN_AFTER(raise_event, step)
  local ret = expectations.Expectation("Wait for SDL start", test.mobileConnection)
  ret.event = event
  event_dispatcher:AddEvent(test.mobileConnection, ret.event, ret)
  test:AddExpectation(ret)
  return ret
end

--- SDL status check
-- @treturn number SDL state
--
-- SDL.STOPPED = 0 Completed the work correctly
--
-- SDL.RUNNING = 1 Running
--
-- SDL.CRASH = -1 Crash
--
-- SDL.IDLE = -2 Idle (for remote only)
function SDL:CheckStatusSDL()
  if config.remoteConnection.enabled then
    local result, data = ATF.remoteUtils.app:CheckAppStatus(config.SDL)
    if result then
      if data == remote_constants.APPLICATION_STATUS.IDLE then
        return self.IDLE
      elseif data == remote_constants.APPLICATION_STATUS.NOT_RUNNING then
        return self.STOPPED
      elseif data == remote_constants.APPLICATION_STATUS.RUNNING then
        return self.RUNNING
      end
      error("Remote utils: unknown Appstatus of SDL was received")
    end
    error("Remote utils: unable to get Appstatus of SDL")
  else
    local testFile = os.execute('test -e sdl.pid')
    if testFile then
      local testCatFile = os.execute('test -e /proc/$(cat sdl.pid)')
      if not testCatFile then
        return self.CRASH
      end
      return self.RUNNING
    end
    return self.STOPPED
  end
end

--- Deleting an SDL process indicator file
function SDL.DeleteFile()
  if os.execute('test -e sdl.pid') then
    os.execute('rm -f sdl.pid')
  end
end

updateSdlPaths()
setAllSdlBuildOptions()
updateSDLLogProperties()

return SDL
