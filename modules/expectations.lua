--- Module which is responsible for expectations handling
--
-- It provides next types: `Expectation` and `ExpectationsList`
--
-- *Dependencies:* `cardinalities`
--
-- *Globals:* `list`, `timestamp()`, `config`
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local cardinalities = require('cardinalities')

local Expectations = { }
--- Predefined table that represents failed expectation
Expectations.FAILED = { }
--- Predefined table that represents success expectation
Expectations.SUCCESS = { }

--- Type which represents single expectation
-- @type Expectation
function Expectations.Expectation(name, connection)
  local mt = { __index = { } }

  --- Perform actions from actions list
  -- @tparam table data Data for actions
  function mt.__index:Action(data)
    for i = 1, #self.actions do
      self.actions[i](self, data)
    end
  end

  --- Set boundary values (timesLE and timesGE) for expected event occurences
  -- @tparam Cardinality|string|number c Boundary value(s)
  -- @treturn Expectation Current expectation
  function mt.__index:Times(c)
    if type(c) == 'table' and getmetatable(c) == cardinalities.mt then
      self.timesLE = c.lower
      self.timesGE = c.upper
    elseif type(c) == 'string' then
      self.timesLE = tonumber(c)
      self.timesGE = tonumber(c)
    elseif type(c) == 'number' then
      self.timesLE = c
      self.timesGE = c
    else
      error("Expectation:Times() must be called with number or Cardinality argument")
    end
    if self.timesLE == 0 and self.timesGE == 0 then
      self.isDelayNeedsToBeApplied = true
    end
    return self
  end

  --- Set current expectation as pinned (expected during whole test)
  -- @treturn Expectation Current expectation
  function mt.__index:Pin()
    self.pinned = true
    if list then list:Pin(self) end
    return self
  end

  --- Set current expectation as not pinned (expected during one test step where was defined)
  -- @treturn Expectation Current expectation
  function mt.__index:Unpin()
    self.pinned = false
    if list then list:Unpin(self) end
    return self
  end

  --- Add to current expectation actions list new action which will be done only one time
  -- @tparam function func Function for addding
  -- @treturn Expectation Current expectation
  function mt.__index:DoOnce(func)
    local idx = #self.actions + 1
    table.insert(self.actions,
      function(self, data)
        func(self, data)
        table.remove(self.actions, idx)
      end)
    return self
  end

  --- Add to current expectation actions list new action
  -- @tparam function func Function for addding
  -- @treturn Expectation Current expectation
  function mt.__index:Do(func)
    table.insert(self.actions, func)
    return self
  end

  --- Set timeout for current expectation
  -- @tparam number ms Timeout in msec
  -- @treturn Expectation Current expectation
  function mt.__index:Timeout(ms)
    self.timeout = ms
    return self
  end

  --- Perform base validation of expectation and set result into `Test`
  function mt.__index:validate()
    if self.isAtLeastOneFail == true then
      if config.checkAllValidations == false or self.timesGE == nil or self.occurences == self.timesGE then
        self.status = Expectations.FAILED
      end
    end
    -- Check Timeout status
    if not self.status and timestamp() - self.ts > self.timeout then
      self.status = Expectations.FAILED
      self.errorMessage["Timeout"] = string.format("%s: Timeout expired", self)
    end
    if self.occurences >= self.timesLE then
      -- Check if Times criteria is valid
      if self.timesGE and self.occurences > self.timesGE then
        self.status = Expectations.FAILED
        self.errorMessage["Times"] = "The most allowed occurences boundary exceed"
      elseif not self.status then
        self.status = Expectations.SUCCESS
      end
      -- Now check out the Sequence criteria
      for _, e in ipairs(self.after) do
        if not e.status then
          exp.status = Expectations.FAILED
          exp.errorMessage["Sequence"] =
          string.format("\nSequence order violated:\n\"%s\""..
            " must have got occured before \"%s\"", e, exp)
        end
      end
    end
  end

  --- Perform special validation of expectation and set result into `Test`
  -- @tparam function func Function for special validation of expectation
  -- @treturn Expectation Current expectation
  function mt.__index:ValidIf(func)
    if not self.verifyData then self.verifyData = {} end
    self.verifyData[#self.verifyData + 1] = function(self, data)
      local valid, msg = func(self, data)
      if not valid then
        self.isAtLeastOneFail = true
        if not self.errorMessage["ValidIf"] then
          self.errorMessage["ValidIf"] = ""
        end
        if msg ~= nil and msg ~= "" then
          self.errorMessage["ValidIf"] = self.errorMessage["ValidIf"] .. "\n" .. tostring(msg)
        end
      else
        if msg ~= nil and msg ~= "" then
          if not self.warningMessage["WARNING"] then
            self.warningMessage["WARNING"] = ""
          end
          self.warningMessage["WARNING"] = self.warningMessage["WARNING"] .. "\n" .. tostring(msg)
        end
      end
    end
    return self
  end

  function mt:__tostring() return self.name end

  local e =
  {
    timesLE = 1, -- Times Less or Equal
    timesGE = 1, -- Times Greater or Equal
    after = { }, -- Expectations that should get complied before this one
    ts = timestamp(), -- Timestamp
    timeout = 10500, -- Maximum allowed age
    name = name, -- Name to display in error message if failed
    connection = connection, -- Network connection
    occurences = 0, -- Expectation complience times
    errorMessage = { }, -- If failed, error message to display
    warningMessage = { }, -- Warning message to display
    actions = { }, -- Sequence of actions to be executed when complied
    pinned = false, -- True if the expectation is pinned
    list = nil, -- ExpectationsList the expectation belongs to
    isAtLeastOneFail = false, -- True if at least one validation fails
    isDelayNeedsToBeApplied = false -- True if delay for zero occurrence expectation needs to be applied
  }

  setmetatable(e, mt)
  return e
end

--- Type which represents list of expectations
-- @type ExpectationsList
function Expectations.ExpectationsList()
  local mt = { __index = {} }

  --- Add expectation into list of expectations
  -- @tparam Expectation exp Expectation to add
  function mt.__index:Add(exp)
    if exp.pinned then
      table.insert(self.pinned, exp)
      exp.index = #self.pinned
    else
      table.insert(self.expectations, exp)
      exp.index = #self.expectations
    end
  end

  --- Remove expectation from list of expectations
  -- @tparam Expectation exp Expectation to remove
  function mt.__index:Remove(exp)
    if exp.pinned then
      table.remove(self.pinned, exp.index)
      for i = exp.index, #self.pinned do
        self.pinned[i].index = i
      end
    else
      table.remove(self.expectations, exp.index)
      for i = exp.index, #self.expectations do
        self.expectations[i].index = i
      end
    end
  end

  --- Clear list of expectations
  function mt.__index:Clear()
    self.expectations = { }
  end

  --- Check whether list of expectations is empty
  -- @treturn boolean True if list of expectations is empty
  function mt.__index:Empty()
    return #self.expectations == 0
  end

  --- Check whether any expectation from list of expectations is appeared
  -- @treturn boolean True if any of expectations from list of expectations is appeared
  function mt.__index:Any(func)
    for _, e in ipairs(self.expectations) do
      if func(e) then return true end
    end
    return false
  end

  --- Create iterator for list of expectations
  -- @treturn function Iterator for list of expectations
  function mt.__index:List()
    return pairs(self.expectations)
  end


  function mt:__pairs() return pairs(self.expectations) end

  function mt:__ipairs()
    local function expnext(t, i)
      if self.expectations[i + 1] then
        return i + 1, self.expectations[i + 1]
      elseif self.pinned[i - #self.expectations + 1] then
        return i - #self.expectations + 1, self.pinned[i - #self.expectations + 1]
      else
        return nil
      end
    end
    return expnext, self.expectations, 0
  end

  --- Set expectation as pinned (expected during whole test)
  -- @tparam Expectation e Expectation to be pinned
  function mt.__index:Pin(e)
    for i = 1, #self.expectations do
      if self.expectations[i] == e then
        table.remove(self.expectations, i)
        table.insert(self.pinned, e)
        break
      end
    end
  end

  --- Set expectation as not pinned (expected during one test step where was defined)
  -- @tparam Expectation e Expectation to be unpinned
  function mt.__index:Unpin(e)
    for i = 1, #self.pinned do
      if self.pinned[i] == e then
        table.remove(self.pinned, i)
        table.insert(self.expectations, e)
        break
      end
    end
  end
  local res = { pinned = { }, expectations = { } }
  setmetatable(res, mt)
  return res
end

return Expectations
