--- Module which is responsible for mobile expectations handling
--
-- It provides next types: `Expectation` and `ExpectationsList`
--
-- *Dependencies:* `expectations`, `events`
--
-- *Globals:* `event_dispatcher`
-- @module expectations.session_expectations
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local expectations = require('expectations')
local events = require('events')

local Expectation = expectations.Expectation
local Event = events.Event

local SessionExpectations = {}
local mt = { __index = { } }

--- Type which represents single mobile expectation
-- @type MobileExpectations

--- Expectation of specific event
-- @tparam Event event Event which is expected
-- @tparam string name Event name
-- @treturn Expectation Created expectation
function mt.__index:ExpectEvent(event, name)
  local ret = Expectation(name, self.session.connection)
  ret.event = event
  event_dispatcher:AddEvent(self.session.connection, event, ret)
  self.session.exp_list:Add(ret)
  return ret
end

--- Expectation of any event
-- @treturn Expectation Expectation table for any unprocessed event
function mt.__index:ExpectAny()
  local event = Event()
  event.level = 1
  event.matches = function(_, data)
    return data.sessionId == self.session.sessionId.get()
  end
  local ret = Expectation("any unprocessed data", self.session.connection)
  ret.event = event
  event_dispatcher:AddEvent(self.session.connection, event, ret)
  self.session.exp_list:Add(ret)
  return ret
end

--- Construct instance of MobileExpectations type
-- @tparam MobileSession session Mobile session
-- @treturn MobileExpectations Constructed instance
function SessionExpectations.MobileExpectations(session)
  local res = { }
  res.session = session
  setmetatable(res, mt)
  return res
end

return SessionExpectations
