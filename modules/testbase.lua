---- Base test script executor.
--
-- Runs all new methods with a first Capital letter as a test steps.
-- Test steps are being executed one by one and interrupt execution is case of
-- any critical issues (each test step could be marked as Critical)
--
-- For component overview description and a list of responsibilities, please, follow [ATF SAD Component View](https://smartdevicelink.com/en/guides/pull_request/93dee199f30303b4b26ec9a852c1f5261ff0735d/atf/components-view/#test-base).
--
-- *Dependencies:* `qt`, `event_dispatcher`, `events`, `expectations`, `console`, `format`, `SDL`, `exit_codes`, `config`
--
-- *Globals:* `xmlReporter`, `qt`, `critical()`, `description()`, `timestamp()`, `atf_logger`, `print_stopscript()`,
-- `is_redirected`, `config`, `event_dispatcher`, `quit`, `timeoutTimer`
-- @module testbase
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local ed = require("event_dispatcher")
local events = require("events")
local expectations = require('expectations')
local console = require('console')
local fmt = require('format')
local SDL = require('SDL')
local exit_codes = require('exit_codes')
local util = require ("atf.util")

local Test = { }

local Expectation = expectations.Expectation
local SUCCESS = expectations.SUCCESS
local FAILED = expectations.FAILED

local STOPPED = SDL.STOPPED
local RUNNING = SDL.RUNNING
local CRASH = SDL.CRASH

local total_testset_result = true

--- Support table for controlling test steps execution status
local control = qt.dynamic()

--- Check whether character is capital
-- @tparam string c Character for check
-- @treturn boolean True in case parameter is capital letter
local function isCapital(c)
  return 'A' <= c and c <= 'Z'
end

--- Clear system resources after test run was finished
local function finishTestCaseRun()
  if SDL.autoStarted then
    SDL:StopSDL()
  end

  local connections = {"hmiConnection", "remoteConnection"}
  for _, connection in pairs(connections) do
    if Test[connection] then
      Test[connection]:Close()
    end
  end

  Test.current_case_name = nil
  util.runner.print_stopscript()
  xmlReporter:finalize()
  if total_testset_result == false then
    quit(exit_codes.failed)
  else
    quit()
  end
end

os.setlocale("C")

--- Module Test members
-- @section Test

local mt =
{
  __index =
  {
    --- List of test steps
    test_cases = { },
    --- List of test step names
    case_names = { },
    --- List of test step descriptions
    descriptions = { },
    --- Current test step name
    current_case_name = nil,
    --- Current test step index in lists
    current_case_index = 0,
    --- Flag which defines whether current test step is critical
    current_case_mandatory = false,
    --- List of test step expectations
    expectations_list = expectations.ExpectationsList(),
    --- Add expectation to list of expectations
    -- @function AddExpectation
    -- @tparam table self Test
    -- @tparam Expectation e Expectation to be added
    AddExpectation = function(self,e)
      self.expectations_list:Add(e)
    end,
    --- Remove expectation from list of expectations
    -- @function RemoveExpectation
    -- @tparam table self Test
    -- @tparam Expectation e Expectation to be removed
    RemoveExpectation = function(self, e)
      self.expectations_list:Remove(e)
    end,
  },
  __newindex = function(t, k, v)
    local firstLetter = string.sub(k, 1, 1)
    if type(v) == "function" and isCapital(firstLetter)then
      local function testcase(test)
        --- Global functions
        -- @section Global

        --- Set current test step description
        --  @tparam string desc Description
        function description(desc)
          t.descriptions[k] = desc
        end
        --- Set current test step criticalness
        --  Failed critical test step stops all following tests execution
        --  @tparam boolean val New bool value of current test criticalness
        function critical(val)
          t.current_case_mandatory = val
        end
        t.current_case_name = k
        t.current_case_mandatory = false
        v(test)
        t.ts = timestamp()
      end
      t.case_names[testcase] = k
      table.insert(t.test_cases, testcase)
    else
      rawset(t, k, v)
    end
  end,
  __metatable = { }
}

--- Runs next Test Case or quit ATF execution
-- Test case is any testbase inheritor
-- with a first capital letter
-- @lfunction control.runNextCase
function control.runNextCase()
  Test.isStepCompleted = false
  Test.ts = timestamp()
  Test.current_case_time = atf_logger.formated_time(true)
  Test.current_case_index = Test.current_case_index + 1
  local testcase = Test.test_cases[Test.current_case_index]
  if testcase then
    Test.current_case_name = Test.case_names[testcase]
    xmlReporter.AddCase(Test.current_case_name)
    if Test.caseTitles and Test.caseTitles[Test.current_case_index] then
      for _, title in pairs(Test.caseTitles[Test.current_case_index]) do
        print(console.setattr(title, "green", 2))
        atf_logger.LOGTestCaseStart(title)
      end
    end
    atf_logger.LOGTestCaseStart(Test.current_case_name)
    testcase(Test)


  else
    finishTestCaseRun()
  end
end

--- Support method for asynchronous start Tests execution
-- @lfunction control.start
function control:start()
  -- if 'color' is not set, it is true as default value
  if config.color == nil then config.color = true end
  if is_redirected then config.color = false end
  SDL.DeleteFile()
  self:next()
end

--- Checks Test Case result and SDL status
--- In case of any critical issues - interrupts Test Suit execution
local function CheckStatus()
  if Test.current_case_name == nil or Test.current_case_name == '' then return end
  -- Check the test status
  local success = true
  local errorMessage = {}
  local warningMessage = {}
  if SDL:CheckStatusSDL() == CRASH then
    if SDL.exitOnCrash == true then
      success = false
    end
    print(console.setattr("SDL has unexpectedly crashed or stop responding!", "cyan", 1))
    critical(SDL.exitOnCrash)
    SDL.DeleteFile()
  end
  --- Perform delay for the time defined in 'zeroOccurrenceTimeout' configuration parameter
  --  Create expectation on a custom event and then raise this event after timeout
  --  @tparam Connection pConnection Network connection (Mobile or HMI)
  local function wait(pConnection)
    local timeout = config.zeroOccurrenceTimeout
    local event = events.Event()
    event.level = 3
    event.matches = function(event1, event2) return event1 == event2 end
    local ret = Expectation("Wait", pConnection)
    ret.event = event
    ret:Timeout(timeout + 5000)
    event_dispatcher:AddEvent(pConnection, event, ret)
    Test:AddExpectation(ret)
    Test:RunAfter(function() event_dispatcher:RaiseEvent(pConnection, event) end, timeout)
  end
  for _, v in Test.expectations_list:List() do
    if v.isDelayNeedsToBeApplied then
      v.isDelayNeedsToBeApplied = false
      wait(v.connection)
    end
  end
  if Test.expectations_list:Any(function(e) return not e.status end) then return end
  if Test.isStepCompleted == false then Test.isStepCompleted = true return end
  for _, e in ipairs(Test.expectations_list) do
    if e.status ~= SUCCESS then
      success = false
      total_testset_result = false
    end
    if not e.pinned and e.connection then
      event_dispatcher:RemoveEvent(e.connection, e.event)
    end
    for k, v in pairs(e.errorMessage) do
      errorMessage[e.name .. ": " .. k] = v
    end
    for k, v in pairs(e.warningMessage) do
      warningMessage[e.name .. ": " .. k] = v
    end
  end
  fmt.PrintCaseResult(Test.current_case_time, Test.current_case_name, success, errorMessage, warningMessage, timestamp() - Test.ts)
  xmlReporter.CaseMessageTotal(Test.current_case_name,{ ["result"] = success, ["timestamp"] = (timestamp() - Test.ts)} )
  if (not success) then xmlReporter.AddMessage("ErrorMessage", {["Status"] = "FAILED"}, errorMessage ) end
  Test.expectations_list:Clear()
  Test.current_case_name = nil
  if Test.current_case_mandatory and not success then
    SDL:StopSDL()
    if SDL.exitOnCrash == true then
      quit(exit_codes.aborted)
    end
  end
  control:next()
end

--- Fail the current Test execution
-- @param self TestBase table
-- @param cause reason of test fail
-- @lfunction FailTestCase
local function FailTestCase(self, cause)
  local exp = expectations.Expectation("AutoFail")
  exp.status = FAILED
  table.insert(exp.errorMessage, cause)
  Test.expectations_list:Add(exp)
  CheckStatus()
end

--- Skipp the current Test execution
-- @param self TestBase table
local function SkipTest(self)
  quit(exit_codes.skipped)
end

--- Supports method for async Test Case status validation
-- @lfunction control.start
function control:checkstatus()
  event_dispatcher:validateAll()
  CheckStatus()
end

--- Execute 'func' after defined timeout
local function runAfter(self, func, timeout)
  local d = qt.dynamic()
  d.timeout = function(pTimer)
    func()
    self.timers[pTimer] = nil
  end

  local timer = timers.Timer()
  self.timers[timer] = true
  qt.connect(timer, "timeout()", d, "timeout()")
  timer:setSingleShot(true)
  timer:start(timeout)
end

--- Testbase module initialization
local function main()
  setmetatable(Test, mt)

  qt.connect(control, "next()", control, "runNextCase()")

  rawset(Test, "FailTestCase", FailTestCase)
  rawset(Test, "SkipTest", SkipTest)
  rawset(Test, "RunAfter", runAfter)

  event_dispatcher = ed.EventDispatcher()
  event_dispatcher:OnPostEvent(CheckStatus)
  timeoutTimer = timers.Timer()
  qt.connect(timeoutTimer, "timeout()", control, "checkstatus()")

  timeoutTimer:start(400)
  control:next()
end

-- Execute main and return result metatable
main()

return Test
