--- Module which provides interface for emulate connection with HMI for SDL
--
-- *Dependencies:* `json`, `api_loader`
--
-- *Globals:* `data`, `xmlReporter`
-- @module hmi_connection
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local json = require("json")
local api_loader = require("modules/api_loader")

local HmiConnection = { mt = { __index = { } } }

--- Type which provides interface for emulate connection with HMI for SDL
-- @type Connection

--- Connect with SDL
function HmiConnection.mt.__index:Connect()
  self.connection:Connect()
end

--- Read result codes from HMI API
-- @treturn table Result codes
local function getResultCodes( )
  local hmi_schema = api_loader.init("data/HMI_API.xml")
  return hmi_schema.interface["Common"].enum["Result"]
end

local resultCodes = getResultCodes()

--- Send message from HMI to SDL
-- @tparam string text Message
function HmiConnection.mt.__index:Send(text)
  xmlReporter.AddMessage("hmi_connection","Send",{["json"] = tostring(text)})
  self.connection:Send(text)
end

--- Send request message from HMI to SDL
-- @tparam string methodName Method name
-- @tparam table params Request parameters
-- @treturn number Request id
function HmiConnection.mt.__index:SendRequest(methodName, params)
  data = {}
  self.requestId = self.requestId + 1
  data.jsonrpc = "2.0"
  data.id = self.requestId
  data.method = methodName
  data.params = params
  local text = json.encode(data)
  self:Send(text)
  xmlReporter.AddMessage("hmi_connection",{["RequestId"] = tostring(self.requestId),["Type"] = "SendRequest"},{ ["methodName"] = methodName,["params"]=params } )
  return self.requestId
end

--- Send notification message from HMI to SDL
-- @tparam string methodName Method name
-- @tparam table params Response parameters
function HmiConnection.mt.__index:SendNotification(methodName, params)
  xmlReporter.AddMessage("hmi_connection","SendNotification",{ ["methodName"] = methodName, ["params"] = params } )
  local data = {}
  data.method = methodName
  data.jsonrpc = "2.0"
  data.params = params
  local text = json.encode(data)
  self:Send(text)
end

--- Send normal response message from HMI to SDL
-- @tparam number id Request id
-- @tparam string methodName Method name
-- @tparam number code Result code
-- @tparam table params Response parameters
function HmiConnection.mt.__index:SendResponse(id, methodName, code, params)
  xmlReporter.AddMessage("hmi_connection","SendResponse",{ ["id"] = id, ["methodName"] = tostring(methodName), ["code"] = code , ["params"] = params} )
  local data = {}
  self.requestId = self.requestId + 1
  data.jsonrpc = "2.0"
  data.id = id
  data.result = {
    method = methodName,
    code = resultCodes[code]
  }
  if params ~= nil then
    for k, v in pairs(params) do
      data.result[k] = v
    end
  end
  local text = json.encode(data)
  self:Send(text)
end

--- Send error response message from HMI to SDL
-- @tparam number id Message id
-- @tparam string methodName Method name
-- @tparam number code Result code
-- @tparam string errorMessage Error message
function HmiConnection.mt.__index:SendError(id, methodName, code, errorMessage)
  xmlReporter.AddMessage("hmi_connection","SendError",{["id"] = id, ["methodName"] = methodName, ["code"] = code,["errorMessage"] = errorMessage } )
  local data = {}
  data.error = {}
  data.error.data = {}
  data.id = id
  data.jsonrpc = "2.0"
  data.error.data.method = methodName
  data.error.code = resultCodes[code]
  data.error.message = errorMessage
  local text = json.encode(data)
  self:Send(text)
end

--- Set handler for OnInputData
-- @tparam function func Handler function
function HmiConnection.mt.__index:OnInputData(func)
  self.connection:OnInputData(function(_, data)
      func(self, data)
    end)
end

--- Set handler for OnConnected
-- @tparam function func Handler function
function HmiConnection.mt.__index:OnConnected(func)
  self.connection:OnConnected(function() func(self) end)
end

--- Set handler for OnDisconnected
-- @tparam function func Handler function
function HmiConnection.mt.__index:OnDisconnected(func)
  self.connection:OnDisconnected(function() func(self) end)
end

--- Close connection
function HmiConnection.mt.__index:Close()
  self.connection:Close()
end

--- Construct instance of Connection type
-- @tparam WebSocketConnection connection Lower level connection
-- @treturn Connection Constructed instance
function HmiConnection.Connection(connection)
  local res = { }
  res.connection = connection
  res.requestId = 1000
  setmetatable(res, HmiConnection.mt)
  return res
end

return HmiConnection
