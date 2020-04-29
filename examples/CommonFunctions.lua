local CommonFunctions = {}
local mobile_session = require('mobile_session')
local json = require('json4lua/json/json')

function CommonFunctions:newTestCasesGroup(ParameterOrMessage)

	NewTestSuiteNumber =  1

	local message = ""

	--Print new lines to separate test cases group in test report
	if ParameterOrMessage == nil then
		message = "Test Suite For Parameter:"
	elseif type(ParameterOrMessage)=="table" then
		local Prameter = ParameterOrMessage

        for i = 1, #Prameter  do
			if type(Prameter[i]) == "number" then
				message =  message .. "[" .. tostring(Prameter[i]) .. "]"
			else
				if message == "" then
					message = tostring(Prameter[i])
				else
					local len  = string.len(message)
					if string.sub(message, len -1, len) == "]" then
						message =  message .. tostring(Prameter[i])
					else
						message =  message .. "." .. tostring(Prameter[i])
					end


				end
			end
		end
		message =  "Test Suite For Parameter: " .. message

	else
		message = ParameterOrMessage
    end

	Test["Suite_" .. tostring(NewTestSuiteNumber)] = function(self)

		local  length = 80
		local spaces = length - string.len(message)
		--local line1 = string.rep(" ", math.floor(spaces/2)) .. message
		local line1 = message
		local line2 = string.rep("-", length)

		print("\27[33m" .. line2 .. "\27[0m")
		print("")
		print("")
		print("\27[33m" .. line1 .. "\27[0m")
		print("\27[33m" .. line2 .. "\27[0m")

	end


end

function CommonFunctions:ActivationApp(self, AppNumber, TestCaseName)

	local TCName
	if TestCaseName ==nil then
		TCName = "Activation_App"
	else
		TCName = TestCaseName
	end

	Test[TCName] = function(self)

		local Input_AppId
		if AppNumber == nil then
			Input_AppId = self.applications[config.application1.registerAppInterfaceParams.appName]
		else
			Input_AppId = Apps[AppNumber].appID
		end

		local deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"

		--hmi side: sending SDL.ActivateApp request
		local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = Input_AppId})
		EXPECT_HMIRESPONSE(RequestId)
		:Do(function(_,data)
			if
				data.result.isSDLAllowed ~= true then
				local RequestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", {language = "EN-US", messageCodes = {"DataConsent"}})

				--hmi side: expect SDL.GetUserFriendlyMessage message response
				--TODO: update after resolving APPLINK-16094.
				--EXPECT_HMIRESPONSE(RequestId,{result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
				EXPECT_HMIRESPONSE(RequestId)
				:Do(function(_,data)
					--hmi side: send request SDL.OnAllowSDLFunctionality
					--self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality", {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = "127.0.0.1"}})
					self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality", {allowed = true, source = "GUI", device = {id = deviceMAC, name = "127.0.0.1"}})

					--hmi side: expect BasicCommunication.ActivateApp request
					EXPECT_HMICALL("BasicCommunication.ActivateApp")
					:Do(function(_,data)
						--hmi side: sending BasicCommunication.ActivateApp response
						self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {})
					end)
					:Times(AnyNumber())
				end)

			end
		end)

		--mobile side: expect notification
		EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"})
	end
end

function CommonFunctions:DelayedExp(time)
  local event = events.Event()
  event.matches = function(self, e) return self == e end
  EXPECT_EVENT(event, "Delayed event")
  	:Timeout(time+1000)
  RUN_AFTER(function()
              RAISE_EVENT(event, event)
            end, time)
end

return CommonFunctions
