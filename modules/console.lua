--- Module that provides functions for working with the console
--
-- *Dependencies:* none
--
-- *Globals:* `c`, `b`, `u`, `suffix`
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local console = { }

--- Build attribute that represents string with applied style
-- @tparam string string Attribute string
-- @tparam string color Attribute style modifier color
-- @tparam string bold Attribute style modifier bold
-- @tparam string underline Attribute style modifier underline
-- @treturn string Attribute with applied style
function console.setattr(string, color, bold, underline)
  if color == "black" then c = '30'
  elseif color == "red" then c = '31'
  elseif color == "green" then c = '32'
  elseif color == "brown" then c = '33'
  elseif color == "blue" then c = '34'
  elseif color == "magenta" then c = '35'
  elseif color == "cyan" then c = '36'
  elseif color == "white" then c = '37'
  end
  if bold == 1 then b = '2' end
  if bold == 2 then b = '22' end
  if bold == 3 then b = '1' end
  if underline then u = '4' else u = '24' end
  local prefix = nil
  if c then
    prefix = c
  end
  if b then
    if prefix then prefix = prefix .. ';' end
    prefix = prefix .. b
  end
  if u then
    if prefix then prefix = prefix .. ';' end
    prefix = prefix .. u
  end
  if prefix then
    prefix = '\27[' .. prefix .. 'm'
    suffix = '\27[0m'
  else
    prefix = ''
    suffix= ''
  end
  return prefix .. string .. suffix
end

return console
