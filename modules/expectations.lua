local module = { }
module.FAILED = { }
module.SUCCESS = { }

local cardinalities = require('cardinalities')
function module.Expectation(name, connection)
  local mt = { __index = { } }
  function mt.__index:Action(data)
    for i = 1, #self.actions do
      self.actions[i](self, data)
    end
  end
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
    return self
  end
  function mt.__index:Pin()
    self.pinned = true
    if list then list:Pin(self) end
    return self
  end
  function mt.__index:Unpin()
    self.pinned = false
    if list then list:Unpin(self) end
    return self
  end
  function mt.__index:DoOnce(func)
    local idx = #self.actions + 1
    table.insert(self.actions,
      function(self, data)
        func(self, data)
        table.remove(self.actions, idx)
      end)
    return self
  end
  function mt.__index:Do(func)
    table.insert(self.actions, func)
    return self
  end
  function mt.__index:Timeout(ms)
    self.timeout = ms
    return self
  end
  function mt.__index:validate()
    -- Check Timeout status
    if not self.status and timestamp() - self.ts > self.timeout then
      self.status = module.FAILED
      self.errorMessage["Timeout"] = string.format("%s: Timeout expired", self)
    end
    if self.occurences >= self.timesLE then
      -- Check if Times criteria is valid
      if self.timesGE and self.occurences > self.timesGE then
        self.status = module.FAILED
        self.errorMessage["Times"] = "The most allowed occurences boundary exceed"
      elseif not self.status then
        self.status = module.SUCCESS
      end
      -- Now check out the Sequence criteria
      for _, e in ipairs(self.after) do
        if not e.status then
          exp.status = module.FAILED
          exp.errorMessage["Sequence"] =
          string.format("\nSequence order violated:\n\"%s\""..
            " must have got occured before \"%s\"", e, exp)
        end
      end
    end
  end
  function mt.__index:ValidIf(func)
    if not self.verifyData then self.verifyData = {} end
    self.verifyData[#self.verifyData + 1] = function(self, data)
      local valid, msg = func(self, data)
      if not valid then
        self.status = module.FAILED
        self.errorMessage["ValidIf"] = msg
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
    timeout = 10000, -- Maximum allowed age
    name = name, -- Name to display in error message if failed
    connection = connection, -- Network connection
    occurences = 0, -- Expectation complience times
    errorMessage = { }, -- If failed, error message to display
    actions = { }, -- Sequence of actions to be executed when complied
    pinned = false, -- True if the expectation is pinned
    list = nil -- ExpectationsList the expectation belongs to
  }

  setmetatable(e, mt)
  return e
end
function module.ExpectationsList()
  local mt = { __index = {} }
  function mt.__index:Add(e)
    if e.pinned then
      table.insert(self.pinned, e)
      e.index = #self.pinned
    else
      table.insert(self.expectations, e)
      e.index = self.expectations
    end
  end
  function mt.__index:Remove(e)
    if e.pinned then
      table.remove(self.pinned, e.index)
      for i = e.index, #self.pinned do
        self.pinned[i].index = i
      end
    else
      table.remove(self.expectations)
      for i = e.index, #self.expectations do
        self.expectations[i].index = i
      end
    end
  end
  function mt.__index:Clear()
    self.expectations = { }
  end
  function mt.__index:Empty()
    return #self.expectations == 0
  end
  function mt.__index:Any(func)
    for _, e in ipairs(self.expectations) do
      if func(e) then return true end
    end
    return false
  end
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
  function mt.__index:Pin(e)
    for i = 1, #self.expectations do
      if self.expectations[i] == e then
        table.remove(self.expectations, i)
        table.insert(self.pinned, e)
        break
      end
    end
  end
  function mt.__index.Unpin(e)
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

return module
