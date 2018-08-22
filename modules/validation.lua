---- *LEGACY* RPC validator
--
-- Load HMI API to table
--
-- *Dependencies:* `xml`
--
-- *Globals:* `loadEnums()`, `loadStructs()`
-- @module validation
-- @warning investigate legacy status and remove
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local xml = require('xml')
local Validation = { }
--- Classes from HMI schema
Validation.classes =
{
  String = { },
  Integer = { },
  Float = { },
  Boolean = { },
  Struct = { },
  Enum = { }
}
--- Enumerations from HMI schema
Validation.enum = { }
--- Structures from HMI schema
Validation.struct = { }

local hmi_api = xml.open("HMI_API.xml")
if not hmi_api then error("HMI_API.xml not found") end

--- Global functions
-- @section Global

--- Load enumerations from HMI schema for validation
-- @tparam userdata api Reference to opened HMI_API document
function loadEnums(api)
  local enums = api:xpath("/interfaces/interface/enum")
  for _, e in ipairs(enums) do
    local enum = { }
    local i = 1
    for _, item in ipairs(e:children("element")) do
      enum[item:attr("name")] = i
      i = i + 1
    end
    print(e:parent():attr("name") .. "." .. e:attr("name"))
    Validation.enum[e:parent():attr("name") .. "." .. e:attr("name")] = enum
  end
end

--- Load structures from HMI schema for validation
-- @tparam userdata api Reference to opened HMI_API document
function loadStructs(api)
  local structs = api:xpath("/interfaces/interface/struct")
  for _, s in ipairs(structs) do
    local struct = { }
    for _, item in ipairs(s:children("param")) do
      struct[item:attr("name")] = item:attributes()
    end
    Validation.struct[s:parent():attr("name") .. "." .. s:attr("name")] = struct
  end

  while true do
    local has_unresolved = false
    local unresolved = ""
    for n, s in pairs(Validation.struct) do
      for _, p in pairs(s) do
        if type(p.type) == 'string' then
          if p.type == "Integer" then
            p.class = Validation.classes.Integer
          elseif p.type == "String" then
            p.class = Validation.classes.String
          elseif p.type == "Float" then
            p.class = Validation.classes.Float
          elseif p.type == "Boolean" then
            p.class = Validation.classes.Boolean
          elseif Validation.enum[p.type] then
            p.class = Validation.classes.Enum
            p.type = Validation.enum[p.type]
          elseif Validation.struct[p.type] then
            p.class = Validation.classes.Struct
            p.type = Validation.struct[p.type]
          else
            has_unresolved = true
            unresolved = p.type
          end
        end
      end
    end
    if not has_unresolved then break end
  end
end

loadEnums(hmi_api)
loadStructs(hmi_api)

return Validation
