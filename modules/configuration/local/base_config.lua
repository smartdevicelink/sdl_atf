--- Module which provides ATF base configuration
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local config = { }

--- Define path to SDL binary
-- Example: "/home/user/sdl_build/bin"
config.pathToSDL = "/home/db/ramdrv/b/dev/p/bin"
config.pathToSDLPolicyDB = "policy.sqlite"

return config
