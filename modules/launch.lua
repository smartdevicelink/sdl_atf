--- Script which runs test scripts
--
-- *Dependencies:* `atf.util`
--
-- *Globals:* none
-- @script launch
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local util = require ("atf.util")

util.commandLine.declare_opt("-c", "--config", util.commandLine.consts.RequiredArgument, "Config folder")
util.commandLine.declare_long_opt("--mobile-connection", util.commandLine.consts.RequiredArgument, "Mobile connection IP")
util.commandLine.declare_long_opt("--mobile-connection-port", util.commandLine.consts.RequiredArgument, "Mobile connection port")
util.commandLine.declare_long_opt("--hmi-connection", util.commandLine.consts.RequiredArgument, "HMI connection IP")
util.commandLine.declare_long_opt("--hmi-connection-port", util.commandLine.consts.RequiredArgument, "HMI connection port")
util.commandLine.declare_long_opt("--perflog-connection", util.commandLine.consts.RequiredArgument, "PerfLog connection IP")
util.commandLine.declare_long_opt("--perflog-connection-port", util.commandLine.consts.RequiredArgument, "Perflog connection port")
util.commandLine.declare_long_opt("--report-path", util.commandLine.consts.RequiredArgument, "Path for a report collecting.")
util.commandLine.declare_long_opt("--report-mark", util.commandLine.consts.RequiredArgument, "Specify label of string for marking test report.")
util.commandLine.declare_long_opt("--storeFullSDLLogs", util.commandLine.consts.NoArgument, "Store Full SDL Logs enable")
util.commandLine.declare_long_opt("--heartbeat", util.commandLine.consts.RequiredArgument, "Hearbeat timeout value")
util.commandLine.declare_long_opt("--sdl-core", util.commandLine.consts.RequiredArgument, "Path to folder with SDL binary")
util.commandLine.declare_long_opt("--report-mark", util.commandLine.consts.RequiredArgument, "Marker of testing report")
util.commandLine.declare_long_opt("--security-protocol", util.commandLine.consts.RequiredArgument, "Security protocol type")
util.commandLine.declare_long_opt("--sdl-interfaces", util.commandLine.consts.RequiredArgument, "Path to folder with APIs")

local script_files = util.commandLine.parse_cmdl()
if (#script_files > 0) then
  for _,scpt in ipairs(script_files) do
    util.runner.print_startscript(scpt)
    util.runner.script_execute(scpt)
  end
end
