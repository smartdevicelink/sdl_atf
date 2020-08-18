--- Module which provides ATF base configuration
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local config = { }
--- Flag which defines usage of color for reporting
config.color = true

--- Define timeout for Heartbeat in msec
config.heartbeatTimeout = 7000
--- Define timeout to wait for the events that should not occur
config.zeroOccurrenceTimeout = 2000
--- Flag which defines whether ATF checks all validations for particular expectation or just till the first which fails
config.checkAllValidations = false
--- Define default version of Ford protocol
-- 1 - basic
--
-- 2 - RPC, encryption
--
-- 3 - video/audio streaming, heartbeat
-- 4 - SDL 4.0
config.defaultProtocolVersion = 3
--- Define path to SDL binary
-- Example: "/home/user/sdl_build/bin"
config.pathToSDL = ""
--- Define path to SDL .INI file
config.pathToSDLConfig = ""
--- Define path to SDL Policy database
config.pathToSDLPolicyDB = "policy.sqlite"
--- Define path to SDL interfaces
-- Example: "/home/user/sdl_panasonic/src/components/interfaces"
config.pathToSDLInterfaces = ""
--- Define SDL modification
config.SDL = "smartDeviceLinkCore"
--- Flag which defines behavior of ATF on SDL crash
config.ExitOnCrash = true
--- Flag which defines whether ATF starts SDL on startup
config.autorunSDL = true

--- Web engine
--
--- Define Web engine unique identifier
config.webengineUniqueId = "5lNGKj5n63Hf8QjZPzS7X5yjZWYD0nu6IhKtyQOFRuUZkbY8KOdFRKYOGWrHjVL0"

--- Logs and Reports
--
--- Flag which defines whether ATF displays time of test step run
config.ShowTimeInConsole = true
--- Flag which defines whether ATF performs validation of Mobile and HMI messages by API
config.ValidateSchema = true
--- Flag which defines whether ATF ignores collecting of reports
config.excludeReport = true
--- Flag which defines whether ATF creates full ATF logs (with json files and service messages)
config.storeFullATFLogs = true
--- Flag which defines whether ATF stores full SDLCore logs
config.storeFullSDLLogs = false
--- Define path to collected ATF and SDL logs
config.reportPath = "./TestingReports"
--- Define delays for storing sdl log -"x" before start script
-- and +"x" after end script execution. In milliseconds(ms).
config.x_sdllog = 100
-- Default length of the description for test step
config.length = 85

return config
