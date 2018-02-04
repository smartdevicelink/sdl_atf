--- Module which is responsible for creation table with mobile functions from Mobile_API.xml
--
-- *Dependencies:* `xml`, `config`
--
-- *Globals:* `console`
-- @module function_id
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local xml = require('xml')

local FunctionId = { }

--- Table with mobile functions.
--
-- Record: <function_name> : <function_id>
-- @table mobile_functions
FunctionId.mobile_functions = { }

local mobile_api = xml.open("data/MOBILE_API.xml")

local ids = { }

for _, f in ipairs(mobile_api:xpath("//enum[@name='FunctionID']/element")) do
  ids[f:attr("name")] = f:attr("value")
end

for _, f in ipairs(mobile_api:xpath("//function")) do
  FunctionId.mobile_functions[f:attr("name")] = tonumber(ids[f:attr("functionID")])
end

return FunctionId.mobile_functions
