
--- Module which represents enum of exit codes for ATF
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @module exit_codes
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local exit_codes ={}

--- Test execution was finished with result SUCCESS
exit_codes.success = 0
--- Test execution was finished with result ABORTED (test script issue)
exit_codes.aborted = 1
--- Test execution was finished with result FAILED (SDL issue)
exit_codes.failed = 2
--- Test execution was finished with result WRONG ARGUMENTS (test run issue)
exit_codes.wrong_arg = 3
--- Test execution was finished with result SKIPPED
exit_codes.skipped = 4
return exit_codes
