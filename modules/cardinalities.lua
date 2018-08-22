--- Module that provides type Cardinalities and global functions for simple creation of its instances
--
-- *Dependencies:* `json`, `config`, `atf.stdlib.std.io`, `protocol_handler.ford_protocol_constants`
--
-- *Globals:* `AnyNumber(num)`, `AtLeast(num)`, `AtMost(num)`, `Between(a, b)`, `Exactly(num)`
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

--- Data type which provide 2 boundary values (lower and upper) for set of numbers
-- @type Cardinality
local Cardinalities = { }
Cardinalities.mt = { __index = { } }

--- Construct instance of Cardinality type
-- @tparam number lower Lower boundary value
-- @tparam number upper Upper boundary value
-- @treturn Cardinality Constructed instance
function Cardinalities.Cardinality(lower, upper)
  local c = { }
  c.lower = lower
  c.upper = upper
  setmetatable(c, Cardinalities.mt)
  return c
end

--- Global functions
-- @section Functions

--- Global function which create instance of Cardinality type without bounds
-- @treturn Cardinality Constructed instance
function AnyNumber()
  return Cardinalities.Cardinality(0, nil)
end

--- Global function which create instance of Cardinality type with only lower bound
-- @tparam number num Lower boundary value
-- @treturn Cardinality Constructed instance
function AtLeast(num)
  if num <= 0 then
    error("AtLeast: number must be greater than 0")
  end
  return Cardinalities.Cardinality(num, nil)
end

--- Global function which create instance of Cardinality type with only upper bound
-- @tparam number num Upper boundary value
-- @treturn Cardinality Constructed instance
function AtMost(num)
  if num <= 0 then
    error("AtMost: number must be greater than 0")
  end
  return Cardinalities.Cardinality(0, num)
end

--- Global function which create instance of Cardinality type with both bounds
-- @tparam number a Lower boundary value
-- @tparam number b Upper boundary value
-- @treturn Cardinality Constructed instance
function Between(a, b)
  if (a > b) then
    error("Between: `from' must be less than `to'")
  end
  return Cardinalities.Cardinality(a, b)
end

--- Global function which create instance of Cardinality type with equal bounds
-- @tparam number num Value
-- @treturn Cardinality Constructed instance
function Exactly(num)
  return Cardinalities.Cardinality(num, num)
end

return Cardinalities
