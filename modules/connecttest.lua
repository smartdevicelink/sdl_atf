---- Provides high level interface for test script creation and base precondition snippets
--
--
-- *Dependencies:* `atf.util`, `testbase`, `mobile_connection`, `tcp_connection`, `file_connection`,
-- `mobile_session`, `websocket_connection`, `hmi_connection`, `events`, `expectations`, `function_id`,
-- `SDL`, `exit_codes`, `load_schema`
--
-- *Globals:* `config`, `event_dispatcher`, `xmlReporter`, `table2str`, `func_name_str`, `compareValues`, `qt`, `timers`
-- `event_str`, `critical()`, `errmsg`, `quit()`, `AnyNumber()`, `enableFullLoggintTestCase()`, `disableFullLoggintTestCase()`
-- @module connecttest
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

require('atf.util')
local Test = require('testbase')
local mobile = require("mobile_connection")
local mobile_adapter_controller = require("mobile_adapter/mobile_adapter_controller")
local file_connection = require("file_connection")
local mobile_session = require("mobile_session")
local hmi_adapter_controller = require("hmi_adapter/hmi_adapter_controller")
local hmi_connection = require('hmi_connection')
local events = require("events")
local expectations = require('expectations')
local functionId = require('function_id')
local ATF = require("ATF")
local SDL = require('SDL')
local exit_codes = require('exit_codes')
local load_schema = require('load_schema')
local mob_schema = load_schema.mob_schema
local hmi_schema = load_schema.hmi_schema

local Event = events.Event

local Expectation = expectations.Expectation
local SUCCESS = expectations.SUCCESS
local FAILED = expectations.FAILED

--- Type Test extends Test from testbase module
-- @type Test

--- Remote connection and utils
  Test.remoteConnection = ATF.remoteConnection
  Test.remoteUtils = ATF.remoteUtils

--- HMI connection
Test.hmiConnection = hmi_connection.Connection(hmi_adapter_controller.getHmiAdapter({connection = Test.remoteConnection}))

--- Default mobile connection
Test.getDefaultMobileAdapter = mobile_adapter_controller.getDefaultAdapter

local mobileAdapter = Test.getDefaultMobileAdapter()
local fileConnection = file_connection.FileConnection("mobile.out", mobileAdapter)
Test.mobileConnection = mobile.MobileConnection(fileConnection)

event_dispatcher:AddConnection(Test.hmiConnection)
event_dispatcher:AddConnection(Test.mobileConnection)
--- Notification counter
Test.notification_counter = 1
--- Tist of timers for specific test
Test.timers = { }

function Test.hmiConnection:EXPECT_HMIRESPONSE(id, args)
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
      elseif(table2str(arguments):match('error')) then
        results_args = arguments.error
        results_args2 = arguments.error
      end

      if results_args2 then
        if results_args2.code then
          results_args2 = table.removeKey(results_args2, 'code')
        end
        if results_args2.method then
          results_args2 = table.removeKey(results_args2, 'method')
        elseif results_args2.data and results_args2.data.method then
          results_args2 = table.removeKey(results_args2.data, 'method')
        end
      end

      if func_name == nil and type(data.result) == 'table' then
        func_name = data.result.method
      elseif func_name == nil and type(data.error) == 'table' then
        func_name = data.error.data.method
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
      elseif func_name and results_args and data.error then
        return compareValues(results_args, data.error, "error")
      else
        return compareValues(results_args, data.params, "params")
      end
    end)
  ret.event = event
  event_dispatcher:AddEvent(Test.hmiConnection, event, ret)
  Test:AddExpectation(ret)
  return ret
end



--- Add test step with start SDL
function Test:RunSDL()
  self:runSDL()
end

--- Add critical test step with initialize
-- HMI with base checks
function Test:InitHMI()
  critical(true)
  self:initHMI()
end

--- Add critical test step with performing of onReady communications with base checks
function Test:InitHMI_onReady()
  critical(true)
  self:initHMI_onReady()
end

--- Add critical test step with open
-- default mobile connection
function Test:ConnectMobile()
  critical(true)
  self:connectMobile()
end

--- Add critical test step with start
-- default mobile session on default mobile connection
function Test:StartSession()
  critical(true)
  self:startSession()
end

--- Start SDL
function Test:runSDL()
  if config.autorunSDL ~= true then
    SDL.autoStarted = false
    return
  end
  local result, errmsg = SDL:StartSDL(config.pathToSDL, config.SDL, config.ExitOnCrash)
  if not result then
    quit(exit_codes.aborted)
  end
  SDL.autoStarted = true
end

--- Initialize HMI with base checks
function Test:initHMI()
  local function registerComponent(name, subscriptions)
    local rid = Test.hmiConnection:SendRequest("MB.registerComponent", { componentName = name })
    local exp = EXPECT_HMIRESPONSE(rid)
    if subscriptions then
      for _, s in ipairs(subscriptions) do
        exp:Do(function()
            local rid = Test.hmiConnection:SendRequest("MB.subscribeTo", { propertyName = s })
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
          "BasicCommunication.OnResumeAudioSource",
          "BasicCommunication.OnSystemCapabilityUpdated"
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
      registerComponent("AppService",
        {
          "AppService.OnAppServiceData"
        })
    end)
  self.hmiConnection:Connect()
end

--- Perform onReady communications with base checks
function Test:initHMI_onReady()
  local function ExpectRequest(name, mandatory, params)
    local event = events.Event()
    event.level = 1
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
    event.level = 1
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
      button_capability("PLAY_PAUSE"),
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
  local function image_field(name, width, height)
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
      },
      systemCapabilities = {
          navigationCapability = {
              sendLocationEnabled = true,
              getWayPointsEnabled = true
          },
          phoneCapability = {
              dialNumberEnabled = true
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

  EXPECT_HMICALL("BasicCommunication.UpdateDeviceList")
  :Do(function(_, data) self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {}) end)
  :Times(SDL.buildOptions.webSocketServerSupport == "ON" and AtLeast(1) or AnyNumber())

  self.hmiConnection:SendNotification("BasicCommunication.OnReady")
end

--- Open default mobile conection and add mobile disconnect expectation
function Test:connectMobile()
  -- Disconnected expectation
  EXPECT_EVENT(events.disconnectedEvent, "Disconnected")
  :Pin()
  :Times(AnyNumber())
  :Do(function()
      print("Disconnected!!!")
      quit(exit_codes.aborted)
    end)
    local ret = EXPECT_EVENT(events.connectedEvent, "Connected")
    self.mobileConnection:Connect()
    return ret
end

--- Start default mobile session on default mobile conection
function Test:startSession()
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

--- Global functions
-- @section Global

--- Create expectation for specific HMI resonse and add it to expectation list
-- @tparam number id Correlation identifier
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_HMIRESPONSE(id,...)
  local args = table.pack(...)
  return Test.hmiConnection:EXPECT_HMIRESPONSE(id, args)
end

--- Create expectation for specific HMI notification and add it to expectation list
-- @tparam string name Notification name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_HMINOTIFICATION(name,...)
  local args = table.pack(...)
  local event = events.Event()
  event.matches = function(self, data) return data.method == name end
  local ret = Expectation("HMI notification " .. name, Test.hmiConnection)
  if #args > 0 then
    ret:ValidIf(function(self, data)
        local arguments
        if self.occurences > #args then
          arguments = args[#args]
        else
          arguments = args[self.occurences]
        end
        local correlation_id = Test.notification_counter
        Test.notification_counter = Test.notification_counter + 1
        xmlReporter.AddMessage("EXPECT_HMINOTIFICATION", {["Id"] = correlation_id, ["name"] = tostring(name),["Type"] = "EXPECTED_RESULT"},arguments)
        xmlReporter.AddMessage("EXPECT_HMINOTIFICATION", {["Id"] = correlation_id, ["name"] = tostring(name),["Type"] = "AVALIABLE_RESULT"},data)
        local _res, _err = hmi_schema:Validate(name, load_schema.notification, data.params)
        if (not _res) then return _res,_err end
        return compareValues(arguments, data.params, "params")
      end)
  end
  ret.event = event
  event_dispatcher:AddEvent(Test.hmiConnection, event, ret)
  Test:AddExpectation(ret)
  return ret
end

--- Create expectation for specific HMI call and add it to expectation list
-- @tparam string methodName Method name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_HMICALL(methodName, ...)
  local args = table.pack(...)
  -- TODO: Avoid copy-paste
  local event = events.Event()
  event.matches =
  function(self, data) return data.method == methodName end
  local ret = Expectation("HMI call " .. methodName, Test.hmiConnection)
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
  event_dispatcher:AddEvent(Test.hmiConnection, event, ret)
  Test:AddExpectation(ret)
  return ret
end

--- Create expectation for specific mobile notification from default session and add it to expectation list
-- @tparam string func Notification name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_NOTIFICATION(func, ...)
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
    return Test.mobileSession:ExpectNotification(func,arguments)
  end
  return Test.mobileSession:ExpectNotification(func,args)

end

--- Create expectation for specific mobile notification from any session and add it to expectation list
-- @tparam string funcName Notification name
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_ANY_SESSION_NOTIFICATION(funcName, ...)
  local args = table.pack(...)
  local event = events.Event()
  event.matches = function(_, data)
    return data.rpcFunctionId == functionId[funcName]
  end
  local ret = Expectation(funcName .. " notification", Test.mobileConnection)
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
  event_dispatcher:AddEvent(Test.mobileConnection, event, ret)
  Test.expectations_list:Add(ret)
  return ret
end

--- Run function after specified delay
-- @tparam function func Function to run
-- @tparam number timeout Delay in msec
-- @tparam ?string funcName function name
function RUN_AFTER(func, timeout, funcName)
  func_name_str = "noname"
  if funcName then
    func_name_str = funcName
  end
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, func_name_str,
    {["functionLine"] = debug.getinfo(func, "S").linedefined, ["Timeout"] = tostring(timeout)})
  Test:RunAfter(func, timeout)
end

--- Create expectation for specific mobile response from default session and add it to expectation list
-- @tparam number correlationId Correlation identifier
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_RESPONSE(correlationId, ...)
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, "EXPECTED_RESULT", ... )
  return Test.mobileSession:ExpectResponse(correlationId, ...)
end

--- Create expectation for specific mobile response from any session and add it to expectation list
-- @tparam number correlationId Correlation identifier
-- @tparam table ... Expectation parameters
-- @treturn Expectation Expectation
function EXPECT_ANY_SESSION_RESPONSE(correlationId, ...)
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, {["CorrelationId"] = tostring(correlationId)})
  local args = table.pack(...)
  local event = events.Event()
  event.matches = function(_, data)
    return data.rpcCorrelationId == correlationId
  end
  local ret = Expectation("response to " .. correlationId, Test.mobileConnection)
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
  event_dispatcher:AddEvent(Test.mobileConnection, event, ret)
  Test.expectations_list:Add(ret)
  return ret
end

--- Create expectation for any mobile event and add it to expectation list
-- @treturn Expectation Expectation
function EXPECT_ANY()
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, '')
  return Test.mobileSession:ExpectAny()
end

--- Create expectation for specific mobile event and add it to expectation list
-- @tparam Event event Event for expectation
-- @tparam string name Event name
-- @treturn Expectation Expectation
function EXPECT_EVENT(event, name)
  local ret = Expectation(name, Test.mobileConnection)
  ret.event = event
  event_dispatcher:AddEvent(Test.mobileConnection, event, ret)
  Test:AddExpectation(ret)
  return ret
end

--- Raise specific event
-- @tparam Event event Event
-- @tparam table data Data for rise event
-- @tparam ?string eventName Event name
function RAISE_EVENT(event, data, eventName)
  event_str = "noname"
  if eventName then
    event_str = eventName
  end
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, event_str)
  event_dispatcher:RaiseEvent(Test.mobileConnection, data)
end

--- Create expectation for specific HMI event and add it to expectation list
-- @tparam Event event Event for expectation
-- @tparam string name Event name
-- @treturn Expectation Expectation
function EXPECT_HMIEVENT(event, name)
  xmlReporter.AddMessage(debug.getinfo(1, "n").name, name)
  local ret = Expectation(name, Test.hmiConnection)
  ret.event = event
  event_dispatcher:AddEvent(Test.hmiConnection, event, ret)
  Test:AddExpectation(ret)
  return ret
end

--- Start SDL
-- @tparam string SDLPathName Path to SDL
-- @tparam boolean ExitOnCrash Flag whether Stop ATF in case SDL shutdown
-- @treturn boolean The main result. Indicates whether the launch of SDL was successful
-- @treturn string Additional information on the main SDL startup result
function StartSDL(SDLPathName, ExitOnCrash)
  return SDL:StartSDL(SDLPathName, config.SDL, ExitOnCrash)
end

--- Stop SDL
-- @treturn nil The main result. Always nil.
-- @treturn string Additional information on the main result of stopping SDL
function StopSDL()
  event_dispatcher:ClearEvents()
  Test.expectations_list:Clear()
  return SDL:StopSDL()
end

--- Create test step for enable full ATF logs
function enableFullATFLogs()
  function enableFullLoggintTestCase()
    if (config.storeFullATFLogs) then
      Test:FailTestCase("full ATF logs already enabled")
    else
      config.storeFullATFLogs = true
    end
  end
  Test["EnableFullATFLogs"] = nil
  Test["EnableFullATFLogs"] = enableFullLoggintTestCase
end

--- Create test step for disable full ATF logs
function disableFullATFLogs()
  function disableFullLoggintTestCase()
    if (not config.storeFullATFLogs) then
      Test:FailTestCase("full ATF logs already disabled")
    else
      config.storeFullATFLogs = false
    end
  end
  Test["DisableFullATFLogs"] = nil
  Test["DisableFullATFLogs"] = disableFullLoggintTestCase
end

return Test
