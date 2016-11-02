require('atf.util')
local module = require('testbase')
local mobile = require("mobile_connection")
local tcp = require("tcp_connection")
local file_connection = require("file_connection")
local mobile_session = require("mobile_session")
local websocket = require('websocket_connection')
local hmi_connection = require('hmi_connection')
local events = require("events")
local expectations = require('expectations')
local functionId = require('function_id')
local SDL = require('SDL')

local load_schema = require('load_schema')

local mob_schema = load_schema.mob_schema
local hmi_schema = load_schema.hmi_schema

local Event = events.Event

local Expectation = expectations.Expectation
local SUCCESS = expectations.SUCCESS
local FAILED = expectations.FAILED

module.hmiConnection = hmi_connection.Connection(websocket.WebSocketConnection(config.hmiUrl, config.hmiPort))
local tcpConnection = tcp.Connection(config.mobileHost, config.mobilePort)
local fileConnection = file_connection.FileConnection("mobile.out", tcpConnection)
module.mobileConnection = mobile.MobileConnection(fileConnection)
event_dispatcher:AddConnection(module.hmiConnection)
event_dispatcher:AddConnection(module.mobileConnection)
module.notification_counter=1

function module.hmiConnection:EXPECT_HMIRESPONSE(id, args)
  local event = events.Event()
  event.matches = function(self, data) return data.id == id end
  local ret = Expectation("HMI response " .. id, self)
  ret:ValidIf(function(self, data)
      local arguments
      if self.occurences > #args then
        arguments = args[#args]
      else
        arguments = args[self.occurences]
      end
      xmlReporter.AddMessage("EXPECT_HMIRESPONSE", {["Id"] = tostring(id),["Type"] = "EXPECTED_RESULT"},arguments)
      xmlReporter.AddMessage("EXPECT_HMIRESPONSE", {["Id"] = tostring(id),["Type"] = "AVALIABLE_RESULT"},data)
      local func_name = data.method
      local results_args = arguments
      local results_args2 = arguments
      if(table2str(arguments):match('result')) then
        results_args = arguments.result
        results_args2 = arguments.result
      end
      if results_args2 and results_args2.code then
        results_args2 = table.removeKey(results_args2, 'code')
      end
      if results_args2 and results_args2.method then
        results_args2 = table.removeKey(results_args2, 'method')
      end
      if func_name == nil and type(data.result) == 'table' then
        func_name = data.result.method
      end
      local _res, _err
      _res = true
      if not (table2str(arguments):match('error')) then
        _res, _err = hmi_schema:Validate(func_name, load_schema.response, data.params)
      end
      if (not _res) then
        return _res,_err
      end
      if func_name and results_args and data.result then
        return compareValues(results_args, data.result, "result")
      else
        return compareValues(results_args, data.params, "params")
      end
    end)
  ret.event = event
  event_dispatcher:AddEvent(module.hmiConnection, event, ret)
  module:AddExpectation(ret)
  return ret
end

function EXPECT_HMIRESPONSE(id,...)
  local args = table.pack(...)
  return module.hmiConnection:EXPECT_HMIRESPONSE(id, args)
end

function EXPECT_HMINOTIFICATION(name,...)
  local args = table.pack(...)
  local event = events.Event()
  event.matches = function(self, data) return data.method == name end
  local ret = Expectation("HMI notification " .. name, module.hmiConnection)
  if #args > 0 then
    ret:ValidIf(function(self, data)
        local arguments
        if self.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[self.occurences]
        end
        local correlation_id = module.notification_counter
        module.notification_counter = module.notification_counter + 1
        xmlReporter.AddMessage("EXPECT_HMINOTIFICATION", {["Id"] = correlation_id, ["name"] = tostring(name),["Type"] = "EXPECTED_RESULT"},arguments)
        xmlReporter.AddMessage("EXPECT_HMINOTIFICATION", {["Id"] = correlation_id, ["name"] = tostring(name),["Type"] = "AVALIABLE_RESULT"},data)
        local _res, _err = hmi_schema:Validate(name, load_schema.notification, data.params)
        if (not _res) then return _res,_err end
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(module.hmiConnection, event, ret)
  module:AddExpectation(ret)
  return ret
end

function EXPECT_HMICALL(methodName, ...)
  local args = table.pack(...)
  -- TODO: Avoid copy-paste
  local event = events.Event()
  event.matches =
  function(self, data) return data.method == methodName end
  local ret = Expectation("HMI call " .. methodName, module.hmiConnection)
  if #args > 0 then
    ret:ValidIf(function(self, data)
        local arguments
        if self.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[self.occurences]
        end
        xmlReporter.AddMessage("EXPECT_HMICALL", {["Id"] = data.id, ["name"] = tostring(methodName),["Type"] = "EXPECTED_RESULT"},arguments)
        xmlReporter.AddMessage("EXPECT_HMICALL", {["Id"] = data.id, ["name"] = tostring(methodName),["Type"] = "AVALIABLE_RESULT"},data.params)
        _res, _err = hmi_schema:Validate(methodName, load_schema.request, data.params)
        if (not _res) then return _res,_err end
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(module.hmiConnection, event, ret)
  module:AddExpectation(ret)
  return ret
end

function EXPECT_NOTIFICATION(func,...)
  -- xmlReporter.AddMessage(debug.getinfo(1, "n").name, "EXPECTED_RESULT", ... )
  local args = table.pack(...)
  local args_count = 1
  if #args > 0 then
    local arguments = {}
    if #args > 1 then
      for args_count = 1, #args do
        if(type( args[args_count])) == 'table' then
          table.insert(arguments, args[args_count])
        end
      end
    else
      arguments = args
    end
    return module.mobileSession:ExpectNotification(func,arguments)
  end
  return module.mobileSession:ExpectNotification(func,args)

end

function EXPECT_ANY_SESSION_NOTIFICATION(funcName, ...)
  local args = table.pack(...)
  local event = events.Event()
  event.matches = function(_, data)
    return data.rpcFunctionId == functionId[funcName]
  end
  local ret = Expectation(funcName .. " notification", module.mobileConnection)
  if #args > 0 then
    ret:ValidIf(function(self, data)
        local arguments
        if self.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[self.occurences]
        end
        local _res, _err = mob_schema:Validate(funcName, load_schema.notification, data.payload)
        xmlReporter.AddMessage("EXPECT_ANY_SESSION_NOTIFICATION", {["name"] = tostring(funcName),["Type"]= "EXPECTED_RESULT"}, arguments)
        xmlReporter.AddMessage("EXPECT_ANY_SESSION_NOTIFICATION", {["name"] = tostring(funcName),["Type"]= "AVALIABLE_RESULT"}, data.payload)
        if (not _res) then return _res,_err end
        return compareValues(arguments, data.payload, "payload")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(module.mobileConnection, event, ret)
  module.expectations_list:Add(ret)
  return ret
end

module.timers = { }

function RUN_AFTER(func, timeout, funcName)
  func_name_str = "noname"
  if funcName then
    func_name_str = funcName
  end
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, func_name_str, 
    {["functionLine"] = debug.getinfo(func, "S").linedefined, ["Timeout"] = tostring(timeout)})
  local d = qt.dynamic()
  d.timeout = function(self)
    func()
    module.timers[self] = nil
  end
  local timer = timers.Timer()
  module.timers[timer] = true
  qt.connect(timer, "timeout()", d, "timeout()")
  timer:setSingleShot(true)
  timer:start(timeout)
end

function EXPECT_RESPONSE(correlationId, ...)
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, "EXPECTED_RESULT", ... )
  return module.mobileSession:ExpectResponse(correlationId, ...)
end

function EXPECT_ANY_SESSION_RESPONSE(correlationId, ...)
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, {["CorrelationId"] = tostring(correlationId)})
  local args = table.pack(...)
  local event = events.Event()
  event.matches = function(_, data)
    return data.rpcCorrelationId == correlationId
  end
  local ret = Expectation("response to " .. correlationId, module.mobileConnection)
  if #args > 0 then
    ret:ValidIf(function(self, data)
        local arguments
        if self.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[self.occurences]
        end
        xmlReporter.AddMessage("EXPECT_ANY_SESSION_RESPONSE", "EXPECTED_RESULT", arguments)
        xmlReporter.AddMessage("EXPECT_ANY_SESSION_RESPONSE", "AVALIABLE_RESULT", data.payload)
        return compareValues(arguments, data.payload, "payload")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(module.mobileConnection, event, ret)
  module.expectations_list:Add(ret)
  return ret
end

function EXPECT_ANY()
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, '')
  return module.mobileSession:ExpectAny()
end

function EXPECT_EVENT(event, name)
  local ret = Expectation(name, module.mobileConnection)
  ret.event = event
  event_dispatcher:AddEvent(module.mobileConnection, event, ret)
  module:AddExpectation(ret)
  return ret
end

function RAISE_EVENT(event, data, eventName)
  event_str = "noname"
  if eventName then
    event_str = eventName
  end
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, event_str)
  event_dispatcher:RaiseEvent(module.mobileConnection, data)
end

function EXPECT_HMIEVENT(event, name)
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, name)
  local ret = Expectation(name, module.hmiConnection)
  ret.event = event
  event_dispatcher:AddEvent(module.hmiConnection, event, ret)
  module:AddExpectation(ret)
  return ret
end

function StartSDL(SDLPathName, ExitOnCrash)
  return SDL:StartSDL(SDLPathName, config.SDL, ExitOnCrash)
end

function StopSDL()
  event_dispatcher:ClearEvents()
  module.expectations_list:Clear()
  return SDL:StopSDL()
end

function module:RunSDL()
  self:runSDL()
end

function module:InitHMI()
  critical(true)
  self:initHMI()
end

function module:InitHMI_onReady()
  critical(true)
  self:initHMI_onReady()
end

function module:ConnectMobile()
  critical(true)
  self:connectMobile()
end

function module:StartSession()
  critical(true)
  self:startSession()
end

function module:runSDL()
  if config.autorunSDL ~= true then
    SDL.autoStarted = false
    return
  end
  local result, errmsg = SDL:StartSDL(config.pathToSDL, config.SDL, config.ExitOnCrash)
  if not result then
    SDL:DeleteFile()
    quit(exit_codes.aborted)
  end
  SDL.autoStarted = true
end

function module:initHMI()
  local function registerComponent(name, subscriptions)
    local rid = module.hmiConnection:SendRequest("MB.registerComponent", { componentName = name })
    local exp = EXPECT_HMIRESPONSE(rid)
    if subscriptions then
      for _, s in ipairs(subscriptions) do
        exp:Do(function()
            local rid = module.hmiConnection:SendRequest("MB.subscribeTo", { propertyName = s })
            EXPECT_HMIRESPONSE(rid)
          end)
      end
    end
  end

  EXPECT_HMIEVENT(events.connectedEvent, "Connected websocket")
  :Do(function()
      registerComponent("Buttons", {"Buttons.OnButtonSubscription"})
      registerComponent("TTS")
      registerComponent("VR")
      registerComponent("BasicCommunication",
        {
          "BasicCommunication.OnPutFile",
          "SDL.OnStatusUpdate",
          "SDL.OnAppPermissionChanged",
          "BasicCommunication.OnSDLPersistenceComplete",
          "BasicCommunication.OnFileRemoved",
          "BasicCommunication.OnAppRegistered",
          "BasicCommunication.OnAppUnregistered",
          "BasicCommunication.PlayTone",
          "BasicCommunication.OnSDLClose",
          "SDL.OnSDLConsentNeeded",
          "BasicCommunication.OnResumeAudioSource"
        })
      registerComponent("UI",
        {
          "UI.OnRecordStart"
        })
      registerComponent("VehicleInfo")
      registerComponent("Navigation",
        {
          "Navigation.OnAudioDataStreaming",
          "Navigation.OnVideoDataStreaming"
        })
    end)
  self.hmiConnection:Connect()
end

function module:initHMI_onReady()
  local function ExpectRequest(name, mandatory, params)
    local event = events.Event()
    event.level = 2
    event.matches = function(self, data) return data.method == name end
    return
    EXPECT_HMIEVENT(event, name)
    :Times(mandatory and 1 or AnyNumber())
    :Do(function(_, data)
        xmlReporter.AddMessage("hmi_connection","SendResponse",
          {
            ["methodName"] = tostring(name),
            ["mandatory"] = mandatory ,
            ["params"]= params
          })
        self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", params)
      end)
  end

  local function ExpectNotification(name, mandatory)
    xmlReporter.AddMessage(debug.getinfo(1, "n").name, tostring(name))
    local event = events.Event()
    event.level = 2
    event.matches = function(self, data) return data.method == name end
    return
    EXPECT_HMIEVENT(event, name)
    :Times(mandatory and 1 or AnyNumber())
  end

  ExpectRequest("BasicCommunication.MixingAudioSupported",
    true,
    { attenuatedSupported = true })
  ExpectRequest("BasicCommunication.GetSystemInfo", false,
    {
      ccpu_version = "ccpu_version",
      language = "EN-US",
      wersCountryCode = "wersCountryCode"
    })
  ExpectRequest("UI.GetLanguage", true, { language = "EN-US" })
  ExpectRequest("VR.GetLanguage", true, { language = "EN-US" })
  ExpectRequest("TTS.GetLanguage", true, { language = "EN-US" })
  ExpectRequest("UI.ChangeRegistration", false, { }):Pin()
  ExpectRequest("TTS.SetGlobalProperties", false, { }):Pin()
  ExpectRequest("BasicCommunication.UpdateDeviceList", false, { }):Pin()
  ExpectRequest("VR.ChangeRegistration", false, { }):Pin()
  ExpectRequest("TTS.ChangeRegistration", false, { }):Pin()
  ExpectRequest("VR.GetSupportedLanguages", true, {
      languages = {
        "EN-US","ES-MX","FR-CA","DE-DE","ES-ES","EN-GB","RU-RU",
        "TR-TR","PL-PL","FR-FR","IT-IT","SV-SE","PT-PT","NL-NL",
        "ZH-TW","JA-JP","AR-SA","KO-KR","PT-BR","CS-CZ","DA-DK",
        "NO-NO","NL-BE","EL-GR","HU-HU","FI-FI","SK-SK" }
    })
  ExpectRequest("TTS.GetSupportedLanguages", true, {
      languages = {
        "EN-US","ES-MX","FR-CA","DE-DE","ES-ES","EN-GB","RU-RU",
        "TR-TR","PL-PL","FR-FR","IT-IT","SV-SE","PT-PT","NL-NL",
        "ZH-TW","JA-JP","AR-SA","KO-KR","PT-BR","CS-CZ","DA-DK",
        "NO-NO","NL-BE","EL-GR","HU-HU","FI-FI","SK-SK" }
    })
  ExpectRequest("UI.GetSupportedLanguages", true, {
      languages = {
        "EN-US","ES-MX","FR-CA","DE-DE","ES-ES","EN-GB","RU-RU",
        "TR-TR","PL-PL","FR-FR","IT-IT","SV-SE","PT-PT","NL-NL",
        "ZH-TW","JA-JP","AR-SA","KO-KR","PT-BR","CS-CZ","DA-DK",
        "NO-NO","NL-BE","EL-GR","HU-HU","FI-FI","SK-SK" }
    })
  ExpectRequest("VehicleInfo.GetVehicleType", true, {
      vehicleType =
      {
        make = "Ford",
        model = "Fiesta",
        modelYear = "2013",
        trim = "SE"
      }
    })
  ExpectRequest("VehicleInfo.GetVehicleData", true, { vin = "52-452-52-752" })

  local function button_capability(name, shortPressAvailable, longPressAvailable, upDownAvailable)
    return
    {
      name = name,
      shortPressAvailable = shortPressAvailable == nil and true or shortPressAvailable,
      longPressAvailable = longPressAvailable == nil and true or longPressAvailable,
      upDownAvailable = upDownAvailable == nil and true or upDownAvailable
    }
  end

  local buttons_capabilities =
  {
    capabilities =
    {
      button_capability("PRESET_0"),
      button_capability("PRESET_1"),
      button_capability("PRESET_2"),
      button_capability("PRESET_3"),
      button_capability("PRESET_4"),
      button_capability("PRESET_5"),
      button_capability("PRESET_6"),
      button_capability("PRESET_7"),
      button_capability("PRESET_8"),
      button_capability("PRESET_9"),
      button_capability("OK", true, false, true),
      button_capability("SEEKLEFT"),
      button_capability("SEEKRIGHT"),
      button_capability("TUNEUP"),
      button_capability("TUNEDOWN")
    },
    presetBankCapabilities = { onScreenPresetsAvailable = true }
  }
  ExpectRequest("Buttons.GetCapabilities", true, buttons_capabilities)
  ExpectRequest("VR.GetCapabilities", true, { vrCapabilities = { "TEXT" } })
  ExpectRequest("TTS.GetCapabilities", true, {
      speechCapabilities = { "TEXT", "PRE_RECORDED" },
      prerecordedSpeechCapabilities =
      {
        "HELP_JINGLE",
        "INITIAL_JINGLE",
        "LISTEN_JINGLE",
        "POSITIVE_JINGLE",
        "NEGATIVE_JINGLE"
      }
    })

  local function text_field(name, characterSet, width, rows)
    return
    {
      name = name,
      characterSet = characterSet or "TYPE2SET",
      width = width or 500,
      rows = rows or 1
    }
  end
  local function image_field(name, width, heigth)
    return
    {
      name = name,
      imageTypeSupported =
      {
        "GRAPHIC_BMP",
        "GRAPHIC_JPEG",
        "GRAPHIC_PNG"
      },
      imageResolution =
      {
        resolutionWidth = width or 64,
        resolutionHeight = height or 64
      }
    }

  end

  ExpectRequest("UI.GetCapabilities", true, {
      displayCapabilities =
      {
        displayType = "GEN2_8_DMA",
        textFields =
        {
          text_field("mainField1"),
          text_field("mainField2"),
          text_field("mainField3"),
          text_field("mainField4"),
          text_field("statusBar"),
          text_field("mediaClock"),
          text_field("mediaTrack"),
          text_field("alertText1"),
          text_field("alertText2"),
          text_field("alertText3"),
          text_field("scrollableMessageBody"),
          text_field("initialInteractionText"),
          text_field("navigationText1"),
          text_field("navigationText2"),
          text_field("ETA"),
          text_field("totalDistance"),
          text_field("navigationText"),
          text_field("audioPassThruDisplayText1"),
          text_field("audioPassThruDisplayText2"),
          text_field("sliderHeader"),
          text_field("sliderFooter"),
          text_field("notificationText"),
          text_field("menuName"),
          text_field("secondaryText"),
          text_field("tertiaryText"),
          text_field("timeToDestination"),
          text_field("turnText"),
          text_field("menuTitle"),
          text_field("locationName"),
          text_field("locationDescription"),
          text_field("addressLines"),
          text_field("phoneNumber")
        },
        imageFields =
        {
          image_field("softButtonImage"),
          image_field("choiceImage"),
          image_field("choiceSecondaryImage"),
          image_field("vrHelpItem"),
          image_field("turnIcon"),
          image_field("menuIcon"),
          image_field("cmdIcon"),
          image_field("showConstantTBTIcon"),
          image_field("locationImage")
        },
        mediaClockFormats =
        {
          "CLOCK1",
          "CLOCK2",
          "CLOCK3",
          "CLOCKTEXT1",
          "CLOCKTEXT2",
          "CLOCKTEXT3",
          "CLOCKTEXT4"
        },
        graphicSupported = true,
        imageCapabilities = { "DYNAMIC", "STATIC" },
        templatesAvailable = { "TEMPLATE" },
        screenParams =
        {
          resolution = { resolutionWidth = 800, resolutionHeight = 480 },
          touchEventAvailable =
          {
            pressAvailable = true,
            multiTouchAvailable = true,
            doublePressAvailable = false
          }
        },
        numCustomPresetsAvailable = 10
      },
      audioPassThruCapabilities =
      {
        samplingRate = "44KHZ",
        bitsPerSample = "8_BIT",
        audioType = "PCM"
      },
      hmiZoneCapabilities = "FRONT",
      softButtonCapabilities =
      {
        {
          shortPressAvailable = true,
          longPressAvailable = true,
          upDownAvailable = true,
          imageSupported = true
        }
      }
    })

  ExpectRequest("VR.IsReady", true, { available = true })
  ExpectRequest("TTS.IsReady", true, { available = true })
  ExpectRequest("UI.IsReady", true, { available = true })
  ExpectRequest("Navigation.IsReady", true, { available = true })
  ExpectRequest("VehicleInfo.IsReady", true, { available = true })

  self.applications = { }
  ExpectRequest("BasicCommunication.UpdateAppList", false, { })
  :Pin()
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
      self.applications = { }
      for _, app in pairs(data.params.applications) do
        self.applications[app.appName] = app.appID
      end
    end)

  self.hmiConnection:SendNotification("BasicCommunication.OnReady")
end

function module:connectMobile()
  -- Disconnected expectation
  EXPECT_EVENT(events.disconnectedEvent, "Disconnected")
  :Pin()
  :Times(AnyNumber())
  :Do(function()
      print("Disconnected!!!")
      quit(exit_codes.aborted)
    end)
  self.mobileConnection:Connect()
  return EXPECT_EVENT(events.connectedEvent, "Connected")
end

function module:startSession()
  self.mobileSession = mobile_session.MobileSession(
    self,
    self.mobileConnection,
    config.application1.registerAppInterfaceParams)
  self.mobileSession:Start()
  EXPECT_HMICALL("BasicCommunication.UpdateAppList")
  :Do(function(_, data)
      self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", { })
      self.applications = { }
      for _, app in pairs(data.params.applications) do
        self.applications[app.appName] = app.appID
      end
    end)
end

function enableFullATFLogs()
  function enableFullLoggintTestCase()
    if (config.storeFullATFLogs) then
      module:FailTestCase("full ATF logs already enabled")
    else
      config.storeFullATFLogs = true
    end
  end
  module["EnableFullATFLogs"] = nil
  module["EnableFullATFLogs"] = enableFullLoggintTestCase
end

function disableFullATFLogs()
  function disableFullLoggintTestCase()
    if (not config.storeFullATFLogs) then
      module:FailTestCase("full ATF logs already disabled")
    else
      config.storeFullATFLogs = false
    end
  end
  module["DisableFullATFLogs"] = nil
  module["DisableFullATFLogs"] = disableFullLoggintTestCase
end

return module
