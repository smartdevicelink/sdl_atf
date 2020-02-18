--- Module which is responsible for dispatching events with expectations
--
-- *Dependencies:* `expectations`, `events`
--
-- *Globals:* `config`
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local expectations = require('expectations')
local events = require('events')

--- Type which is responsible for dispatching events with expectations
-- @type EventDispatcher
local Dispatcher = {}
local mt = { __index = { } }

--- Construct instance of EventDispatcher type
-- @treturn EventDispatcher Constructed instance
function Dispatcher.EventDispatcher()
  local res =
  {
    --- Pool of events level 0 (frame events handlers)
    _pool0 = { },
    --- Pool of events level 1 (anyEvent message handlers)
    _pool1 = { },
    --- Pool of events level 2 (message events handlers)
    _pool2 = { },
    --- Pool of events level 3 (connect/disconnect handlers)
    _pool3 = { },
    --- Pre event handler
    preEventHandler = nil,
    --- Post event handler
    postEventHandler = nil
  }
  setmetatable(res, mt)
  return res
end

--- Get Handler
-- @tparam Connection conn Mobile/HMI connection
-- @tparam Event event Event
-- @treturn table Handler
function mt.__index:GetHandler(conn, event)
  local res = self._pool3[conn][event]
  or self._pool2[conn][event]
  or self._pool1[conn][event]
  or self._pool0[conn][event]
  return res
end

--- Find handler for event
-- @tparam Connection connection Mobile/HMI connection
-- @tparam table data Data for find event
-- @treturn Expectation Handler
function mt.__index:FindHandler(connection, data)
  -- Visit all event pools and find matching event
  local function findInPool(pool, data)
    for event, handler in pairs(pool) do
      if event:matches(data) then
        return handler
      end
    end
    return nil
  end

  if data._technical and data._technical.isFrame then
    return findInPool(self._pool0[connection], data)
  end

  return findInPool(self._pool3[connection], data)
      or findInPool(self._pool2[connection], data)
      or findInPool(self._pool1[connection], data)
end

--- Set handler for pre event
-- @tparam function func Pre event handler.
function mt.__index:OnPreEvent(func)
  self.preEventHandler = func
end

--- Set handler for post event
-- @tparam function func Post event handler.
function mt.__index:OnPostEvent(func)
  self.postEventHandler = func
end

--- Validate all expectations
function mt.__index:validateAll()

  local function iter(pool)
    for _, expectation in pairs(pool) do
      expectation:validate()
    end
  end

  for _, pool in pairs(self._pool3) do iter(pool) end
  for _, pool in pairs(self._pool2) do iter(pool) end
  for _, pool in pairs(self._pool1) do iter(pool) end
  for _, pool in pairs(self._pool0) do iter(pool) end
end

--- Subscribe on connection's [[OnInputData]] signal
-- @tparam Connection connection Mobile/HMI connection
function mt.__index:AddConnection(connection)
  local this = self
  self._pool0[connection] = { }
  self._pool1[connection] = { }
  self._pool2[connection] = { }
  self._pool3[connection] = { }
  connection:OnConnected(function (self)
      if this.preEventHandler then
        this.preEventHandler(events.connectedEvent)
      end
      local exp = this:GetHandler(self, events.connectedEvent)
      if exp then
        exp.occurences = exp.occurences + 1
        exp:Action()
        this:validateAll()
      end
      if this.postEventHandler then
        this.postEventHandler(events.connectedEvent)
      end
    end)
  connection:OnDisconnected(function (self)
      if this.preEventHandler then
        this.preEventHandler(events.disconnectedEvent)
      end
      local exp = this:GetHandler(self, events.disconnectedEvent)
      if exp then
        exp.occurences = exp.occurences + 1
        exp:Action()
        this:validateAll()
      end
      if this.postEventHandler then
        this.postEventHandler(events.disconnectedEvent)
      end
    end)
  connection:OnInputData(function (connection, data)
      this:RaiseEvent(connection, data)
    end)
end

--- Raise event
-- @tparam Connection connection Mobile/HMI connection
-- @tparam table data Data for rise event
function mt.__index:RaiseEvent(connection, data)
  if self.preEventHandler and data then
    self.preEventHandler(data)
  end
  local exp = self:FindHandler(connection, data)
  if exp then
    exp.occurences = exp.occurences + 1
    if data then
      if exp.verifyData then
        for _, verifyFunc in pairs(exp.verifyData) do
            verifyFunc(exp, data)
            if (config.checkAllValidations == false) and (exp.isAtLeastOneFail == true) then
              break
            end
        end
      end
      exp:Action(data)
    end
    self:validateAll()
  end
  if self.postEventHandler then
    self.postEventHandler(data)
  end
end

--- Add event with expectation to pools
-- @tparam Connection connection Mobile/HMI connection
-- @tparam Event event Event to be addded
-- @tparam Expectation expectation Expectation for added event
function mt.__index:AddEvent(connection, event, expectation)
  if event.level == 3 then
    self._pool3[connection][event] = expectation
  elseif event.level == 2 then
    self._pool2[connection][event] = expectation
  elseif event.level == 1 then
    self._pool1[connection][event] = expectation
  elseif event.level == 0 then
    self._pool0[connection][event] = expectation
  end
end

--- Remove event with expectation from pools
-- @tparam Connection connection Mobile/HMI connection
-- @tparam Event event Event to be removed
function mt.__index:RemoveEvent(connection, event)
  self._pool3[connection][event] = nil
  self._pool2[connection][event] = nil
  self._pool1[connection][event] = nil
  self._pool0[connection][event] = nil
end

--- Remove all events with expectation from pools
function mt.__index:ClearEvents()
  for connection, _ in pairs(self._pool3) do self._pool3[connection] = { } end
  for connection, _ in pairs(self._pool2) do self._pool2[connection] = { } end
  for connection, _ in pairs(self._pool1) do self._pool1[connection] = { } end
  for connection, _ in pairs(self._pool0) do self._pool0[connection] = { } end
end

return Dispatcher
