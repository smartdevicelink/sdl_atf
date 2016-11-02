local ed = require("event_dispatcher")
local events = require("events")
local expectations = require('expectations')
local console = require('console')
local fmt = require('format')
local SDL = require('SDL')

local exit_codes = require('exit_codes')

local module = { }

local Expectation = expectations.Expectation
local SUCCESS = expectations.SUCCESS
local FAILED = expectations.FAILED

local STOPPED = SDL.STOPPED
local RUNNING = SDL.RUNNING
local CRASH = SDL.CRASH

local total_testset_result = true

local control = qt.dynamic()

local function isCapital(c)
  return 'A' <= c and c <= 'Z'
end

os.setlocale("C")

local mt =
{
  __index =
  {
    test_cases = { },
    case_names = { },
    descriptions = { },
    current_case_name = nil,
    current_case_index = 0,
    current_case_mandatory = false,
    expectations_list = expectations.ExpectationsList(),
    AddExpectation = function(self,e)
      self.expectations_list:Add(e)
    end,
    RemoveExpectation = function(self, e)
      self.expectations_list:Remove(e)
    end,
  },
  __newindex = function(t, k, v)
    local firstLetter = string.sub(k, 1, 1)
    if type(v) == "function" and isCapital(firstLetter)then
      local function testcase(test)
        function description(desc)
          t.descriptions[k] = desc
        end
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

function control.runNextCase()
  module.ts = timestamp()
  module.current_case_time = atf_logger.formated_time(true)
  module.current_case_index = module.current_case_index + 1
  local testcase = module.test_cases[module.current_case_index]
  if testcase then
    module.current_case_name = module.case_names[testcase]
    xmlReporter.AddCase(module.current_case_name)
    atf_logger.LOGTestCaseStart(module.current_case_name)
    testcase(module)
  else
    if SDL.autoStarted then
      SDL:StopSDL()
    end
    module.current_case_name = nil
    print_stopscript()
    xmlReporter:finalize()
    if total_testset_result == false then
      quit(exit_codes.failed)
    else 
      quit()
    end
  end
end

function control:start()
  -- if 'color' is not set, it is true as default value
  if config.color == nil then config.color = true end
  if is_redirected then config.color = false end
  SDL:DeleteFile()
  self:next()
end

setmetatable(module, mt)

qt.connect(control, "next()", control, "runNextCase()")
local function CheckStatus()
  if module.current_case_name == nil or module.current_case_name == '' then return end
  -- Check the test status
  local success = true
  local errorMessage = {}
  if SDL:CheckStatusSDL() == CRASH then
    success = false
    print(console.setattr("SDL has unexpectedly crashed or stop responding!", "cyan", 1))
    critical(SDL.exitOnCrash)
    SDL:DeleteFile()
  elseif module.expectations_list:Any(function(e) return not e.status end) then return end
  for _, e in ipairs(module.expectations_list) do
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
  end
  fmt.PrintCaseResult(module.current_case_time, module.current_case_name, success, errorMessage, timestamp() - module.ts)
  xmlReporter.CaseMessageTotal(module.current_case_name,{ ["result"] = success, ["timestamp"] = (timestamp() - module.ts)} )
  if (not success) then xmlReporter.AddMessage("ErrorMessage", {["Status"] = "FAILD"}, errorMessage ) end
  module.expectations_list:Clear()
  module.current_case_name = nil
  if module.current_case_mandatory and not success then
    SDL:StopSDL()
    quit(exit_codes.aborted)
  end
  control:next()
end

local function FailTestCase(self, cause)
  module.expectations_list:Clear()
  local exp = expectations.Expectation(cause)
  exp.status = FAILED
  exp.errorMessage = { ["AutoFail"] = cause }
  module.expectations_list:Add(exp)
  CheckStatus()
end
rawset(module, "FailTestCase", FailTestCase)

event_dispatcher = ed.EventDispatcher()
event_dispatcher:OnPostEvent(CheckStatus)
timeoutTimer = timers.Timer()
qt.connect(timeoutTimer, "timeout()", control, "checkstatus()")
function control:checkstatus()
  event_dispatcher:validateAll()
  CheckStatus()
end
timeoutTimer:start(400)
control:next()

return module
