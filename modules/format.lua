--- Module which is responsible for formated output into console
--
-- *Dependencies:* `console`
--
-- *Globals:* `config`
-- @module format
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

--- Singleton table which is used for perform formated output into console
-- @table Format
local Format = { }
local console = require('console')

--- Print formated information about test step result into console
-- @tparam string startCaseTime String representation of time of test step start
-- @tparam string caseName Test step name
-- @tparam boolean success Boolean representation of successes of test step
-- @tparam string errorMessage Error message
-- @tparam number timespan Duration of test step execution in msec
-- @treturn Format Module Format
function Format.PrintCaseResult(startCaseTime, caseName, success, errorMessage, warningMessage, timespan)
  caseName = tostring(caseName)
  if #caseName > config.length then
    caseName = string.sub(caseName, 1, config.length - 3) .. "..."
  else
    caseName = caseName .. string.rep(' ', config.length - #caseName)
  end

  local result
  if config.color then
    result = console.setattr(
      success and "[SUCCESS]" or "[FAIL]",
      success and "green" or "red",
      2, false)
  else
    result = success and "[SUCCESS]" or "[FAIL]"
  end

  if config.ShowTimeInConsole == true then
    print(string.format("[%s] %s %s (%d ms)",startCaseTime, caseName, result, timespan))
  else
    print(string.format("%s %s (%d ms)", caseName, result, timespan))
  end

  if not success and errorMessage then
    for k, v in pairs(errorMessage) do
      local errmsg = " " .. k .. ": " .. v
      if config.color then
        print(console.setattr(errmsg, "cyan", 1))
      else
        print(errmsg)
      end
    end
  end
  -- Print warnings
  if warningMessage then
    for k, v in pairs(warningMessage) do
      local errmsg = " " .. k .. ": " .. v
      if config.color then
        print(console.setattr(errmsg, "brown", 1))
      else
        print(errmsg)
      end
    end
  end
  return Format
end

return Format
