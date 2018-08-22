Test = require('connecttest') 
require('cardinalities')
local events = require('events')  
local mobile_session = require('mobile_session')

local CommonFunctions = require('examples/CommonFunctions')

config.deviceMAC = "12ca17b49af2289436f303e0166030a21e525d266e209267433801a8fd4071a0"
config.defaultProtocolVersion = 2
---------------------------------------------------------------------------------------------
-------------------------------------------Preconditions-------------------------------------
---------------------------------------------------------------------------------------------


-- Add group for tests
CommonFunctions:newTestCasesGroup("------------------------------- Preconditions ----------------------------------")
-- All tests should begin with a capital letter.
--Description: Activation App by sending SDL.ActivateApp  
function Test:ActivationApp()
  
  --hmi side: sending SDL.ActivateApp request
  local RequestId = self.hmiConnection:SendRequest("SDL.ActivateApp", { appID = self.applications["Test Application"]})

  --hmi side: expect SDL.ActivateApp response
  EXPECT_HMIRESPONSE(RequestId)
    :Do(function(_,data)
      --In case when app is not allowed, it is needed to allow app
      if
        data.result.isSDLAllowed ~= true then

          --hmi side: sending SDL.GetUserFriendlyMessage request
          local RequestId = self.hmiConnection:SendRequest("SDL.GetUserFriendlyMessage", 
                    {language = "EN-US", messageCodes = {"DataConsent"}})

          --hmi side: expect SDL.GetUserFriendlyMessage response
          --TODO: Update after resolving APPLINK-16094 EXPECT_HMIRESPONSE(RequestId,{result = {code = 0, method = "SDL.GetUserFriendlyMessage"}})
          EXPECT_HMIRESPONSE(RequestId)
            :Do(function(_,data)

              --hmi side: send request SDL.OnAllowSDLFunctionality
              self.hmiConnection:SendNotification("SDL.OnAllowSDLFunctionality", 
                {allowed = true, source = "GUI", device = {id = config.deviceMAC, name = "127.0.0.1"}})


              --hmi side: expect BasicCommunication.ActivateApp request
              EXPECT_HMICALL("BasicCommunication.ActivateApp")
                :Do(function(_,data)

                  --hmi side: sending BasicCommunication.ActivateApp response
                  self.hmiConnection:SendResponse(data.id,"BasicCommunication.ActivateApp", "SUCCESS", {})

                end)
                :Times(2)


            end)

    end
  end)
  
  --mobile side: expect notification
  EXPECT_NOTIFICATION("OnHMIStatus", {hmiLevel = "FULL", systemContext = "MAIN"}) 
end


-- Usually all data files should be just in files folder
Test["PutFile"] = function(self)
    --mobile request
    local CorIdPutFile = self.mobileSession:SendRPC(
                "PutFile",
                {
                  syncFileName = "icon.png",
                  fileType = "GRAPHIC_PNG",
                  persistentFile = false,
                  systemFile = false, 
                }, "examples/icon.png")

    --mobile response
    EXPECT_RESPONSE(CorIdPutFile, { success = true, resultCode = "SUCCESS"})
    :Timeout(12000)   
  end

---------------------------------------------------------------------------------------------
-------------------------------------------Basic RPCs----------------------------------------
---------------------------------------------------------------------------------------------
--------------------------------------------------------------------------------

 CommonFunctions:newTestCasesGroup("------------------------------- Basic RPCs -------------------------------------")

function Test:AddCommand()
  --mobile side: sending AddCommand request
  local cid = self.mobileSession:SendRPC("AddCommand",
                      {
                        cmdID = 10,
                        menuParams =  
                        { 
                          position = 0,
                          menuName ="Command"
                        }
                      })
  --hmi side: expect UI.AddCommand request
  EXPECT_HMICALL("UI.AddCommand", 
          { 
            cmdID = 10,                   
            menuParams = 
            { 
              position = 0,
              menuName ="Command"
            }
          })
  :Do(function(_,data)
    --hmi side: sending UI.AddCommand response
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
  end)
            
  --mobile side: expect AddCommand response
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })

  --mobile side: expect OnHashChange notification
  EXPECT_NOTIFICATION("OnHashChange")
end 

function Test:DeleteCommand()
  --mobile side: sending DeleteCommand request
  local cid = self.mobileSession:SendRPC("DeleteCommand",
  {
    cmdID = 10
  })

  --hmi side: expect UI.DeleteCommand request
  EXPECT_HMICALL("UI.DeleteCommand", 
  { 
    cmdID = 10
  })
  :Do(function(_,data)
    --hmi side: sending UI.DeleteCommand response
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
  end)      
        
  --mobile side: expect DeleteCommand response 
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })

  --mobile side: expect OnHashChange notification
  EXPECT_NOTIFICATION("OnHashChange")
end   


function Test:SetGlobalProperties()
    
  --mobile side: sending SetGlobalProperties request
  local cid = self.mobileSession:SendRPC("SetGlobalProperties",
  {
    menuTitle = "Menu Title",
    timeoutPrompt = 
    {
      {
        text = "Timeout prompt",
        type = "TEXT"
      }
    },
    vrHelp = 
    {
      {
        position = 1,
        text = "VR help item"
      }
    },
    helpPrompt = 
    {
      {
        text = "Help prompt",
        type = "TEXT"
      }
    },
    vrHelpTitle = "VR help title"   
  })

  --hmi side: expect TTS.SetGlobalProperties request
  EXPECT_HMICALL("TTS.SetGlobalProperties",
  {
    timeoutPrompt = 
    {
      {
        text = "Timeout prompt",
        type = "TEXT"
      }
    },
    helpPrompt = 
    {
      {
        text = "Help prompt",
        type = "TEXT"
      }
    }
  })
  :Timeout(10000)
  :Do(function(_,data)
    --hmi side: sending UI.SetGlobalProperties response
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
  end)

  --hmi side: expect UI.SetGlobalProperties request
  EXPECT_HMICALL("UI.SetGlobalProperties",
  {
    menuTitle = "Menu Title",
    vrHelp = 
    {
      {
        position = 1,
        text = "VR help item"
      }
    },
    vrHelpTitle = "VR help title"
  })
  :Timeout(10000)
  :Do(function(_,data)
    --hmi side: sending UI.SetGlobalProperties response
    self.hmiConnection:SendResponse(data.id, data.method, "SUCCESS", {})
  end)

  --mobile side: expect SetGlobalProperties response
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS"})
  :Timeout(10000)
  
  --mobile side: expect OnHashChange notification
  EXPECT_NOTIFICATION("OnHashChange")
end

function Test:Alert() 

  --mobile side: Alert request  
  local CorIdAlert = self.mobileSession:SendRPC("Alert",
                          {
                               
                            ttsChunks = 
                            { 
                              
                              { 
                                text = "TTSChunkOnly",
                                type = "TEXT",
                              }, 
                            }, 
                          
                          }) 
 

  local SpeakId
  --hmi side: TTS.Speak request 
  EXPECT_HMICALL("TTS.Speak", 
          { 
            ttsChunks = 
            { 
              
              { 
                text = "TTSChunkOnly",
                type = "TEXT",
              }, 
            },
            speakType = "ALERT"
          })
    :Do(function(_,data)
      self.hmiConnection:SendNotification("TTS.Started")
      SpeakId = data.id

      local function speakResponse()
        self.hmiConnection:SendResponse(SpeakId, "TTS.Speak", "SUCCESS", { })

        self.hmiConnection:SendNotification("TTS.Stopped")
      end

      RUN_AFTER(speakResponse, 2000)

    end)
    :ValidIf(function(_,data)
      if #data.params.ttsChunks == 1 then
        return true
      else
        print("ttsChunks array in TTS.Speak request has wrong element number. Expected 1, actual "..tostring(#data.params.ttsChunks))
        return false
      end
    end)
 

    --mobile side: OnHMIStatus notifications
    EXPECT_NOTIFICATION("OnHMIStatus",
                { systemContext = "MAIN", hmiLevel = level, audioStreamingState = "ATTENUATED"    },
                { systemContext = "MAIN",  hmiLevel = level, audioStreamingState = "AUDIBLE"    })
            :Times(AtLeast(1))
            :Timeout(10000)

    --mobile side: Alert response
    EXPECT_RESPONSE(CorIdAlert, { success = true, resultCode = "SUCCESS" })
end



function Test:Speak()
  local Request = {
    ttsChunks =
    {
      {text ="Text1", type ="TEXT"},
      {text ="Text2", type ="TEXT"},
      {text ="Text3", type ="TEXT"},
    }
  }

  --mobile side: sending the request
  local cid = self.mobileSession:SendRPC("Speak", Request)

  --hmi side: expect TTS.Speak request
  EXPECT_HMICALL("TTS.Speak", Request)
  :Do(function(_,data)
    self.hmiConnection:SendNotification("TTS.Started")
    SpeakId = data.id

    local function speakResponse()
      self.hmiConnection:SendResponse(SpeakId, "TTS.Speak", "SUCCESS", { })

      self.hmiConnection:SendNotification("TTS.Stopped")
    end
    RUN_AFTER(speakResponse, 1000)
  end)

  --mobile side: expect the response
  EXPECT_RESPONSE(cid, { success = true, resultCode = "SUCCESS" })

end

------------------------------------------------------------------------------------------------------
-------------------------------------------Testing Stop/Start ----------------------------------------
------------------------------------------------------------------------------------------------------


 CommonFunctions:newTestCasesGroup("------------------------------ Stop/Start SDL ----------------------------------")
function Test:StopSDL()
  StopSDL()
end

function Test:StartSDL()
  StartSDL(config.pathToSDL, config.ExitOnCrash)
end

function Test:InitHMI()
  self:initHMI()
end

function Test:InitHMI_onReady()
  self:initHMI_onReady()
end

function Test:ConnectMobile()
  self:connectMobile()
end

function Test:StartSession()
  self:startSession()
end

function Test:ActivationApp()
  CommonFunctions:ActivationApp(self)
end


----------------------------------------------------------------------------------------------------
-------------------------------------------Testing heartbeat----------------------------------------
----------------------------------------------------------------------------------------------------
 CommonFunctions:newTestCasesGroup("--------------------------------- Heartbeat ------------------------------------")

--  some local functions 
local function userPrint( color, message, nsession )
  print ("\27[" .. tostring(color) .. "m " .. tostring(message) .. " " .. tostring(nsession) .. " \27[0m")
end

local function userPrint2 ( color, message )
  print ("\27[" .. tostring(color) .. "m " .. tostring(message) .. " \27[0m")
end

function Test:RegisterAppSession2()
  self.mobileSession2 = mobile_session.MobileSession(
  self,
  self.mobileConnection,
  config.application2.registerAppInterfaceParams)
  self.mobileSession2.version = 3
  self.mobileSession2.sendHeartbeatToSDL = false
  self.mobileSession2.answerHeartbeatFromSDL = false
  self.mobileSession2.ignoreHeartBeatAck = true
  self.mobileSession2:Start()
  self.mobileSession2:StartService(7)
  CommonFunctions:DelayedExp(20000)  
  self.mobileSession2.sendHeartbeatToSDL = false
  CommonFunctions:DelayedExp(20000)
end

function Test:NoHBToSDLNoDisconnect()
 CommonFunctions:DelayedExp(20000)

  -- hmi side: expect OnAppUnregistered notification
  EXPECT_HMINOTIFICATION("BasicCommunication.OnAppUnregistered", {unexpectedDisconnect = true, appID = HMIAppID})
  :Times(0)

  userPrint (33,"Log: AppSession2 started, HB disabled", self.mobileSession)    
  userPrint (33, "Log: App v.3 disconnection not expected since no HB ACK and timer should be started by SDL till the HB request from app first", "(in TC NoHBToSDLNoDisconnect)") 

end


function Test:RegisterAppSession3()
  self.mobileSession3 = mobile_session.MobileSession(
    self,
    self.mobileConnection,
    config.application2.registerAppInterfaceParams)
  self.mobileSession3.version = 3
  self.mobileSession3:StartHeartbeat()
  self.mobileSession3.sendHeartbeatToSDL = true
  self.mobileSession3.answerHeartbeatFromSDL = false
  self.mobileSession3.ignoreHeartBeatAck = true
  self.mobileSession3:StartService(7)
 end
  
function Test:DisconnectDueToHeartbeat()
  CommonFunctions:DelayedExp(20000)
  userPrint(33, "AppSession3 started, HB enabled", self.mobileSession3) 
  userPrint2(33, "In DisconnectDueToHeartbeat TC disconnection is expected because HB process started by SDL after app's HB request")    
end