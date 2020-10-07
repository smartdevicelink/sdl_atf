--- Module which is responsible for loading Mobile and HMI API validation schema.
--
-- Dependencies: `api_loader`, `schema_validation`
--
-- *Globals:* none
-- @module load_schema
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local api_loader = require('api_loader')
local validator = require('schema_validation')

--- Table with a Mobile and HMI schema's
-- @table LoadSchema
-- @tfield Validator mob_schema Mobile validator
-- @tfield Validator hmi_schema HMI validator
-- @tfield string response Const for Response
-- @tfield string request Const for Request
-- @tfield string notification Const for Notification
local LoadSchema = { }
LoadSchema.response = 'response'
LoadSchema.request = 'request'
LoadSchema.notification = 'notification'
if (not LoadSchema.mob_schema) then
  LoadSchema.mob_api = api_loader.init("data/MOBILE_API.xml")
  local interfaceName = next(LoadSchema.mob_api.interface)
  LoadSchema.mob_api_version = LoadSchema.mob_api.interface[interfaceName].version
  LoadSchema.mob_schema = validator.CreateSchemaValidator(LoadSchema.mob_api)
end
if (not LoadSchema.hmi_schema) then
  LoadSchema.hmi_api = api_loader.init("data/HMI_API.xml")
  LoadSchema.hmi_schema = validator.CreateSchemaValidator(LoadSchema.hmi_api)
end

return LoadSchema
