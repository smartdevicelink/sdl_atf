--- Module which provides APIs validator loader.
--
-- Use `load_schema` for loading Mobile and HMI API validation schema.
--
-- *Dependencies:* `xml`
--
-- *Globals:* `param_name`, `param_data`, `name`
-- @module api_loader
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/)
-- and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local xml = require('xml')

local apiLoader = { }

--- Include result codes that are elements in functions from Mobile Api.
-- Each function with paremeter resultCode that has type Result
-- should contain types of Resultcode directly in function.
-- Other resultCodes are kept in structs
local function LoadResultCodes( param )
  local resultCodes ={}
  local i = 1
  for _, item in ipairs(param:children("element")) do
     local name = item:attr("name")
     resultCodes[i]=name
     i=i + 1
    end
  return resultCodes
end

--- Load parameters in function. Load ResultCodes if
-- type of parameter is "Result"
local function LoadParamsInFunction(param, interface)
  local name = param:attr("name")
  local p_type = param:attr("type")
  local mandatory = param:attr("mandatory")
  local array = param:attr("array")

  if mandatory == nil then
    mandatory = true
  end

  if array == nil then
    array = false
  end

  local result_codes = nil
  if name == "resultCode" and p_type == "Result" then
    result_codes  = LoadResultCodes(param)
  end

  local data = {}
  data["type"]=p_type
  data["mandatory"]= mandatory
  data["array"] = array
  data["minlength"] = tonumber(param:attr("minlength"))
  data["maxlength"] = tonumber(param:attr("maxlength"))
  data["minsize"] = tonumber(param:attr("minsize"))
  data["maxsize"] = tonumber(param:attr("maxsize"))
  data["minvalue"] = tonumber(param:attr("minvalue"))
  data["maxvalue"] = tonumber(param:attr("maxvalue"))
  data["defvalue"] = tonumber(param:attr("defvalue"))
  data["resultCodes"] = result_codes
  data["since"] = param:attr("since")
  data["deprecated"] = param:attr("deprecated")

  return name, data
end

--- Load Enums values from API
 local function LoadEnums(api, dest)
   for first, v in pairs (dest.interface) do
    for _, s in ipairs(v.body:children("enum")) do
      local name = s:attr("name")
      dest.interface[first].enum[name]={}
      local i = 1
      for _,e in ipairs(s:children("element")) do
        local enum_value = e:attr("name")

        local value =  e:attr("value")
        if tonumber(value) ~= nil then
          i = tonumber(value)
        end
        dest.interface[first].enum[name][enum_value]=i
        i= i + 1
      end
    end
  end
 end

--- Load structures from API
 local function LoadStructs(api, dest)
   for first, v in pairs (dest.interface) do
    for _, s in ipairs(v.body:children("struct")) do
      local name = s:attr("name")
      local temp_param = {}
      local temp_func = {}
      temp_func["name"] = name
      for _, item in ipairs(s:children("param")) do
        param_name, param_data = LoadParamsInFunction(item, first)
        temp_param[param_name] = param_data
      end
      temp_func["param"] = temp_param
      dest.interface[first].struct[name]=temp_func
    end
   end
 end


--- Load functions with all fields from API
local function LoadFunction( api, dest  )
  for first, v in pairs (dest.interface) do
    for _, s in ipairs(v.body:children("function")) do
      local name = s:attr("name")
      local msg_type = s:attr("messagetype")
      local temp_func = {}
      local temp_param = {}
      temp_func["name"] = name
      temp_func["messagetype"] = msg_type
      for _, item in ipairs(s:children("param")) do
        param_name, param_data = LoadParamsInFunction(item, first)
        temp_param[param_name] = param_data
      end

      temp_func["param"] = temp_param
      dest.interface[first].type[msg_type].functions[name]=temp_func
    end
  end
end

local function GetAPIVersion(version_str)
  local version_arr = {0,0,0}
  local index = 0
  for i in string.gmatch(version_str, "([^.]+)") do
      version_arr[index] = i
      index = index + 1
  end
  local version = {
      majorVersion = version_arr[0],
      minorVersion = version_arr[1],
      patchVersion = version_arr[2]
  }
  return version
end

--- Load interfaces from api. Each function, enum and struct will be
-- kept inside appropriate interface
local function LoadInterfaces( api, dest )
  local interfaces = api:xpath("//interface")
  for _, s in ipairs(interfaces) do
    name = s:attr("name")
    version_str = s:attr("version")
    dest.interface[name] ={}
    dest.interface[name].body = s
    dest.interface[name].type={}
    dest.interface[name].type['request']={}
    dest.interface[name].type['request'].functions={}
    dest.interface[name].type['response']={}
    dest.interface[name].type['response'].functions={}
    dest.interface[name].type['notification']={}
    dest.interface[name].type['notification'].functions={}
    dest.interface[name].enum={}
    dest.interface[name].struct={}
    dest.interface[name].version = GetAPIVersion(version_str)
  end
end

--- Parse api file to lua table.
-- Each function, enum and struct will be
-- kept inside appropriate interface
-- @tparam string path Path to the xml file
-- @tparam string include_parent_name Parent name
-- @treturn table lua table with all xml RPCs
function apiLoader.init(path, include_parent_name)
  apiLoader.include_parent_name = include_parent_name
  local result = {}
  result.interface = { }

  local _api = xml.open(path)
  if not _api then error(path .. " not found") end

  LoadInterfaces(_api, result)
  LoadEnums(_api, result)
  LoadStructs(_api, result)

  LoadFunction(_api, result)
  return result
end

return apiLoader
