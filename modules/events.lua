--- Module which is responsible for events with expectations handling
--
-- *Dependencies:* none
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

--- Singleton table which provide predefined events and interface for construction new events.
-- @table Events
-- @tfield Event connectedEvent Predefined connected event
-- @tfield Event disconnectedEvent Predefined disconnected event
-- @tfield Event timeoutEvent Predefined timeout event
local Events = {}
local event_mt = { __index = { } }
---
Events.connectedEvent = { level = 3 }
Events.disconnectedEvent = { level = 3 }
Events.timeoutEvent = { level = 3 }

setmetatable(Events.connectedEvent, event_mt)
setmetatable(Events.disconnectedEvent, event_mt)
setmetatable(Events.timeoutEvent, event_mt)

--- Type which represents event in ATF event-expectation system
-- @type Event

--- Construct instance of Event type
-- @treturn Event Constructed instance
function Events.Event()
  local ret = {
    --- Level of event
    level = 2
  }
  setmetatable(ret, event_mt)
  return ret
end

--- Event comparation function
-- @treturn boolean True if event data matched to conditions
function event_mt.__index:matches() return false end

return Events
