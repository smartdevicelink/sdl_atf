--- Module which provides constants for remote connection
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @module remote.remote_constants
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local RemoteConstants = {}

--- Application status enumeration
RemoteConstants.APPLICATION_STATUS = {
  IDLE = "-1",
  NOT_RUNNING = "0",
  RUNNING = "1"
}
--- Error code enumeration
RemoteConstants.ERROR_CODE = {
  SUCCESS = 0,
  FAILED  = -1,
  READ_FAILURE = -2,
  WRITE_FAILURE = -3,
  PATH_NOT_FOUND = -4,
  CLOSE_FAILURE = -5,
  OPEN_FAILURE = -6,
  NO_CONNECTION = -7,
  EXCEPTION_THROWN = -8,
  TIMEOUT_EXPIRED = -9,
  ALREADY_EXISTS = -10
}

RemoteConstants.PARAMETER_TYPE = {
  NIL = 0,
  INT = 1,
  DOUBLE = 2,
  BOOLEAN = 3,
  STRING = 4
}

return RemoteConstants
