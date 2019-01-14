--- The module which is responsible for managing SDL from ATF
--
-- *Dependencies:* `os`, `sdl_logger`, `config`, `atf.util`
--
-- *Globals:* `sleep()`, `CopyFile()`, `CopyInterface()`, `xmlReporter`, `console`, `ATF`
-- @module SDL
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('os')
local sdl_logger = require('sdl_logger')
local config = require('config')
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
--- Update SDL logger config in order SDL will be able to write logs through Telnet
local function updateSDLLogProperties()
  if config.storeFullSDLLogs then
    local paramsToUpdate = {
      {
        name = "log4j.rootLogger",
        value = "ALL, TelnetLogging,Console,SmartDeviceLinkCoreLogFile"
      },
      {
        name = "log4j.appender.TelnetLogging.layout.ConversionPattern",
        value = "%%-5p [%%d{yyyy-MM-dd HH:mm:ss,SSS}][%%t][%%c] %%F:%%L %%M: %%m"
      }
    }
    for _, item in pairs(paramsToUpdate) do
      SDL.LOGGER.set(item.name, item.value)
    end
  end
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
      local _, path = ATF.remoteUtils.file:GetFile(p, n)
      pPathToFile = path
    else
      return nil
    end
  end
  local file = io.open(pPathToFile, "r")
  local content = nil
  if file then
    content = file:read("*all")
    file:close()
  end
  return content
end

local function saveFileContent(pPathToFile, pContent)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pPathToFile)
    local _ = ATF.remoteUtils.file:UpdateFileContent(p, n, pContent)
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
    local _ = ATF.remoteUtils.file:DeleteFile(p, n)
  else
    os.execute( "rm -f " .. pPathToFile)
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
  local out = ""
  local find = false
  for line in pContent:gmatch("[^\r\n]+") do
    if string.match(line, "[; ]*".. pParam ..".*=.*") ~= nil then
        line = pParam .." = \n"
    end
    local ptrn = "^%s*".. pParam .. "%s*=.*"
    if string.find(line, ptrn) then
      if not find then
        line = string.gsub(line, ptrn, pParam .. "=" .. tostring(pValue))
        find = true
      else
        line  = ";" .. line
      end
    end
    out = out .. line .. "\n"
  end
  return out
end

local function backup(pFilePath)
  if config.remoteConnection.enabled then
    local p, n = getPathAndName(pFilePath)
    ATF.remoteUtils.file:BackupFile(p, n)
  else
    os.execute(" cp " .. pFilePath .. " " .. pFilePath .. "_origin" )
  end
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
  if isFileExist(pFilePath .. "_origin") then
    if config.remoteConnection.enabled then
      local p, n = getPathAndName(pFilePath)
      ATF.remoteUtils.file:RestoreFile(p, n)
    else
      os.execute(" cp " .. pFilePath .. "_origin " .. pFilePath )
      os.execute( " rm -f " .. pFilePath .. "_origin" )
    end
  end
end

--- Structure of SDL build options what to be set
local function getDefaultBuildOptions()
  local options = { }
  options.remoteControl = { sdlBuildParameter = "REMOTE_CONTROL", defaultValue = "ON" }
  options.extendedPolicy = { sdlBuildParameter = "EXTENDED_POLICY", defaultValue = "PROPRIETARY" }
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
  return config.pathToSDLConfig .. "smartDeviceLink.ini"
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
  local filePath
  if config.remoteConnection.enabled then
    filePath = SDL.INI.get("LoggerConfigFile")
  else
    filePath = config.pathToSDLConfig .. "log4cxx.properties"
  end
  return filePath
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
  return config.pathToSDLConfig .. SDL.INI.get("PreloadedPT")
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
    ATF.remoteUtils.app:ExecuteCommand("cd " .. p
      .. " && openssl x509 -in " .. n
      .. " -hash -noout | awk '{print $0\".0\"}' | xargs ln -sf " .. n)
  end

  if pIsModuleCrtDefined == nil then pIsModuleCrtDefined = true end
  local allCrts = getAllCrtsFromPEM(pCrtsFileName)
  local crtPath = SDL.addSlashToPath(SDL.INI.get("CACertificatePath"))
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
  local func
  if config.remoteConnection.enabled then
    func = function(...) ATF.remoteUtils.app:ExecuteCommand(...) end
  else
    func = os.execute
  end
  local crtPath = SDL.addSlashToPath(SDL.INI.get("CACertificatePath"))
  func("cd " .. crtPath .. " && find . -type l -not -name 'lib*' -exec rm -f {} \\;")
  func("cd " .. crtPath .. " && rm -rf *" .. ext)
end

SDL.PTS = {}

function SDL.PTS.file()
  return SDL.addSlashToPath(SDL.INI.get("SystemFilesPath")) .. SDL.INI.get("PathToSnapshot")
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
  return config.pathToSDLConfig .. SDL.INI.get("HMICapabilities")
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
  deleteFile(config.pathToSDLPolicyDB)
  if config.remoteConnection.enabled then
    ATF.remoteUtils.app:ExecuteCommand("rm -rf /fs/tmpfs/*")
    ATF.remoteUtils.app:ExecuteCommand("rm -rf /fs/rwdata/storage/sdl/.policy.db.")
  end
  deleteFile(SDL.addSlashToPath(SDL.INI.get("AppStorageFolder")) .. SDL.INI.get("AppInfoStorage"))
end

SDL.Log = {}

function SDL.Log.clean()
  -- if config.remoteConnection.enabled then
  --   local filePath = SDL.addSlashToPath(SDL.INI.get("TargetLogFileHomeDir"))
  --   local filePtrn = SDL.INI.get("TargetLogFileNamePattern")
  --   ATF.remoteUtils.app:ExecuteCommand("rm -rf " ..  filePath .. "*" .. filePtrn)
  -- else
  --   os.execute("rm -rf " .. config.pathToSDL .. "*.log")
  -- end
end

SDL.AppStorage = {}

function SDL.AppStorage.path()
  local filePath = SDL.INI.get("AppStorageFolder")
  if string.len(filePath) > 0 then
    if string.sub(filePath, 1, 1) == "/" then
      return SDL.addSlashToPath(filePath)
    else
      return SDL.addSlashToPath(config.pathToSDL .. filePath)
    end
  end
  return config.pathToSDL
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

function SDL.AppStorage.clean(ppath)
  local func
  local path
  if ppath == nil then
    path = "*"
  else
    path = ppath
  end
  if config.remoteConnection.enabled then
    func = function(...) ATF.remoteUtils.app:ExecuteCommand(...) end
  else
    func = os.execute
  end
  func(" rm -rf " .. SDL.AppStorage.path() .. path)
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
function SDL:StartSDL(pathToSDL, smartDeviceLinkCore, ExitOnCrash)
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
  if config.remoteConnection.enabled then
     result = ATF.remoteUtils.app:StartApp(pathToSDL, smartDeviceLinkCore)
  else
     result = os.execute ('./tools/StartSDL.sh ' .. pathToSDL .. ' ' .. smartDeviceLinkCore)
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
      output = state == 1 and true or false
    else
      local hmiPort = config.hmiAdapterConfig.WebSocket.port
      output = os.execute ("netstat -vatn  | grep " .. hmiPort .. " | grep LISTEN")
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
    else
      error("Remote utils: unable to get Appstatus of SDL")
    end
  else
    local testFile = os.execute ('test -e sdl.pid')
    if testFile then
      local testCatFile = os.execute ('test -e /proc/$(cat sdl.pid)')
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
  if os.execute ('test -e sdl.pid') then
    os.execute('rm -f sdl.pid')
  end
end

config.pathToSDL = SDL.addSlashToPath(config.pathToSDL)
config.pathToSDLConfig = SDL.addSlashToPath(config.pathToSDLConfig)

setAllSdlBuildOptions()

--updateSDLLogProperties()

return SDL
