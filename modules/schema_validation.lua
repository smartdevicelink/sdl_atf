local json = require("json")
local wrong_function_name = "WrongFunctionName"
local generic_response = "GenericResponse"

local module = {
  mt = {__index = { } }
}

function module.CreateSchemaValidator(schema)
  res = { }
  res.schema = schema
  setmetatable(res, module.mt)
  return res
end

local function dump(o)
  if type(o) ~= 'table' then
    return tostring(o)
  end
  local s = '{ '
  for k,v in pairs(o) do
    if type(k) ~= 'number' then k = '"'..k..'"' end
    s = s .. '['..k..'] = ' .. dump(v) .. ','
  end
  return s .. '} \n'  
end

local function errorMsgToString(tbl)
  local tmp = ''
  if type(tbl) ~= 'table' then
    return tostring(tbl)
  end
  for _,v in pairs(tbl) do
    if type(v) == 'table' then
      tmp = tmp ..errorMsgToString(v)
    else
      if v~="" then
       tmp = tmp ..v ..'\n'
      end
    end
  end
  return tmp  
end

-- Check that all mandatory parameters in current schema are existing
local function CheckExistenceOfMandatoryParam(func_schema, user_data, name_of_structure)
  local error_message = {}
  local result = true

  for key,value in pairs(func_schema) do
      if (type(user_data)~='table')then
        return false, "not valid type of "..key .. " expected structure, got "..type(user_data)
      end
      local bool_result = true
      if((user_data[key]==nil) and func_schema[key]["mandatory"] == true) then
        bool_result = false
        if (name_of_structure ~= nil) then 
          key = name_of_structure.."."..key
        end
        error_message["mandatory "..key]= "mandatory parameter "..key.." not present"
      end
      result = bool_result and result
    end
  return result, error_message
end

-- Get names of function or structures
local function GetNames( name )
  if (string.find(name, "%.")) then
    return name:match("([^.]+).([^.]+)")
  end
  return 'Ford Sync RAPI', name
end

-- Compare structs. For each structure should be called 
-- check of mandatory params and types for all elements in the struct
function module.mt.__index:CompareStructs( data_elem, struct_schema,name_of_structure)
  local mandatory_check_result = true --for mandatory param
  local type_parameter_check_result = true -- for correct types of param
  local error_message = {}
  local error_message2 = {}

  local struct_params = struct_schema["param"]
  mandatory_check_result, error_message= CheckExistenceOfMandatoryParam(struct_params, data_elem, name_of_structure)
  type_parameter_check_result, error_message2 = self:CheckTypeOfParam(struct_params, data_elem, error_message, name_of_structure)

  local result = (mandatory_check_result and type_parameter_check_result)
  if (error_message2~=nil) then
    for k,v in pairs(error_message2) do error_message[k] = v end
  end
  return result, error_message
end

-- If data is empty, then we think it is empty array
-- Json's isArray recieve false in this case
-- If data is non empty then we check data using json
local function isArray(data)
  if(type(data)~='table') then return false end
  if next(data) == nil then return true end 
  return json.isArray(data);
end

-- Calls if element has attribute array=true
-- Check that element is array
-- For each element of array call CompareType with isArray=false
function module.mt.__index:CheckTypesInArray( data_elem, schemaElem, nameofParameter, name_of_structure)
  local result = true
  local error_message  = {}
  local elem1 = type(data_elem)
  if isArray(data_elem) then
    for key, value in pairs(data_elem) do
      result, error_message[key]= self:CompareType(value, schemaElem, false, nameofParameter.."."..key, name_of_structure)
    end
  else 
    if name_of_structure~=nil then 
      return false, "Parameter "..name_of_structure.."."..nameofParameter..": got "..elem1..", expected Array"
    end
    return false, "Parameter "..nameofParameter..": got "..elem1..", expected Array"
  end
  return result, error_message
end


-- Check that length of value more than minlength and less then maxlength
local function CheckLength( data_elem, schemaElem, data_name )
  local length = string.len(data_elem)
  if schemaElem["minlength"] ~= nil then
    if(length < schemaElem["minlength"]) then
      return false, "Parameter "..data_name.." get size: "..length..", expected minlength:"..schemaElem["minlength"]
    end
  end
  if schemaElem["maxlength"] ~= nil then
    if(length > schemaElem["maxlength"]) then
      return false, "Parameter "..data_name.." get size: "..length..", expected maxlength:"..schemaElem["maxlength"]
    end
  end
  return true
end

-- Check value is more than minvalue and less then maxvalue
local function CheckValue( data_elem, schemaElem, data_name )
  if schemaElem["minvalue"] ~= nil then
    if(data_elem < schemaElem["minvalue"]) then
        return false, "For parameter "..data_name.." get size: "..data_elem..", expected minvalue:"..schemaElem["minvalue"]
    end
  end
  if schemaElem["maxvalue"] ~= nil then
      if(data_elem > schemaElem["maxvalue"]) then
        return false, "For parameter "..data_name.." get size: "..data_elem..", expected maxvalue:"..schemaElem["maxvalue"]
      end
  end
  return true
end

--Compare types of element
-- For elements with "array = true" process CheckTypesInArray
-- For types "string", "integer" and "float" check values are in intervals from schema 
-- For enum value check that value are included in schema
-- For struct call CompareStructs, where structure will be checked

local function table_contains(table, element)
  for _, value in pairs(table) do
    if value == element then
      return true
    end
  end
  return false
end


function module.mt.__index:CompareType(data_elem, schemaElem, isArray, nameofParameter, name_of_structure)
  local elem1 = type(data_elem)
  if (isArray=='true') then
    return self:CheckTypesInArray(data_elem, schemaElem, nameofParameter, name_of_structure)
  end
  if (schemaElem == 'Integer' or schemaElem == 'Float' or schemaElem == 'Double') then
    if elem1 == 'number'  then
      return CheckValue( data_elem, schemaElem, nameofParameter )
    end
    if name_of_structure~=nil then 
      return false, "Parameter ".. name_of_structure.."."..nameofParameter..": got "..elem1..", expected "..schemaElem 
    end
    return false, "Parameter ".. nameofParameter..": got "..elem1..", expected "..schemaElem       
  elseif schemaElem == 'String' then 
    if elem1 == 'string' then
      return CheckLength( data_elem, schemaElem, nameofParameter )
    end 
    if name_of_structure~=nil then 
      return false, "Parameter ".. name_of_structure.."."..nameofParameter..": got "..elem1..", expected "..schemaElem 
    end
    return false, "Parameter ".. nameofParameter..": got "..elem1..", expected "..schemaElem     
  elseif schemaElem == 'Boolean' then
    if elem1 == 'boolean' then
     return true
    end 
    if name_of_structure~=nil then 
      return false, "Parameter ".. name_of_structure.."."..nameofParameter..": got "..elem1..", expected "..schemaElem 
    end
    return false, "Parameter ".. nameofParameter..": got "..elem1..", expected "..schemaElem    
  end
  local interface_name, complex_elem_name = GetNames(schemaElem)
  -- Check element is enum
  if self.schema.interface[interface_name].enum[complex_elem_name] ~= nil then
    if(self.schema.interface[interface_name].enum[complex_elem_name][data_elem] ~= nil) then 
      return true
    end 
    -- Enum element can be sent as number, so if it belongs to count of data elements, we will set it as acceptable
    if elem1 == 'number' then
      local local_enum = self.schema.interface[interface_name].enum[complex_elem_name]
      if table_contains(local_enum, data_elem) then
        return true
      end
    end
    if name_of_structure~=nil then 
      return false, "Parameter ".. name_of_structure.."."..nameofParameter..": got "..elem1..", expected enum value: "..schemaElem 
    end
    return false, "Parameter ".. nameofParameter.. ": got "..elem1..", expected enum value: " ..schemaElem   
  end
  -- Check element is struct
  if self.schema.interface[interface_name].struct[complex_elem_name] ~= nil then
    if (elem1~='table') then 
      if name_of_structure~=nil then 
        return false, "Parameter ".. name_of_structure.."."..nameofParameter..": got "..elem1..", expected struct: "..schemaElem 
      end
      return false, "Parameter ".. nameofParameter.. ": got "..elem1..", expected struct: "..schemaElem
    end
    if name_of_structure~=nil then 
      name_of_structure = name_of_structure.."."..nameofParameter
      else
      name_of_structure=nameofParameter
    end

    return self:CompareStructs(data_elem, self.schema.interface[interface_name].struct[complex_elem_name],name_of_structure)
  end  
  if name_of_structure~=nil then 
    return false, "Parameter ".. name_of_structure.."."..nameofParameter..": got "..elem1..", expected "..schemaElem 
  end
  return false, "Parameter ".. nameofParameter..": got "..elem1..", expected "..schemaElem
end


local function CountInArray(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end


-- Check element is array
-- Check count of values
local function CheckArray(data_elem, schemaElem, elem_name)
  if not isArray(data_elem) then
    return false
  end   
  arraySize = CountInArray(data_elem)
  local err_msg = {}
  if (schemaElem["minsize"]~=nil) then
    if(arraySize < schemaElem["minsize"]) then
      return false, "n array get size: "..arraySize..", expected minsize:"..schemaElem["minsize"]
    end
  else 
    err_msg["minsize"] =  "WARNING: Problem with API schema "..elem_name..": \"minsize\" does not present in schema with array"
  end
  if (schemaElem["maxsize"]~=nil) then
    if(arraySize > schemaElem["maxsize"]) then
      return false, "in array get size: "..arraySize..", expected maxsize:"..schemaElem["maxsize"]
    end 
  else    
    err_msg["maxsize"] = "WARNING: Problem with API schema "..elem_name..": \"maxsize\" does not present in schema with array"
  end
  return true, err_msg
end

-- Check parameters includes:
-- Check data is table
-- Call checking of Array
-- Call comparation of types with schema's types
function module.mt.__index:CheckTypeOfParam( func_schema, user_data, error_message, name_of_structure)
  local result = true
  local result1 = true
  local  result2 = true
  if (type(user_data)~='table') then
    return false
  end

  for key, value in pairs(user_data) do
    param_from_schema = func_schema[key]
    if param_from_schema == nil then
      result = false
      error_message[key] = "Invalid parameter "..key..", not existing in API schema"
    else
      local isArray = param_from_schema["array"]
      local err_msg = {}
      local temp_res = true
      if (isArray=='true') then
        temp_res, err_msg[1] = CheckArray(value, param_from_schema, key)
      end
      result1 = result1 and temp_res

      temp_res, err_msg[2] = self:CompareType(value, param_from_schema["type"], isArray, key, name_of_structure)
      result2 = result2 and temp_res
      error_message[key]= errorMsgToString(err_msg)
    end
  end
  result = result and result1 and result2
  return result, error_message
end

-- Call checking that mandatory params are existing
-- Call checking that parameters has correct type and values 
function  module.mt.__index:CheckFunctionParams( interface_name, function_name, function_type, user_data )

  local result1 = true --for mandatory param
  local result2 = true -- for correct types of param
  local error_message = {}
  local error_message2 = {}
  local func_schema = self.schema.interface[interface_name].type[function_type].functions[function_name]
  local function_params = func_schema["param"]

  result1, error_message= CheckExistenceOfMandatoryParam(function_params, user_data)
  result2, error_message2 = self:CheckTypeOfParam(function_params, user_data, error_message )

  local result = (result1 and result2)

  -- join errormessages
  for k,v in pairs(error_message2) do error_message[k] = v end
  return result, error_message
end


-- Extract function name and interface from function_id
-- Check that function and interface exist
-- Call CheckFunctionParams for processing function
function module.mt.__index:Compare(function_id,function_type, user_data)
  local result = true
  local error_message = {}
  local types = ''

  if (function_id==nil) then 
    return result, error_message
  end

  if (function_id == wrong_function_name) then
    function_id = generic_response
    local success_code = "SUCCESS"
    user_data["resultCode"]=success_code
  end

  local interface_name, function_name = GetNames(function_id)
  if not user_data then
    user_data = {}
  end
  if (self.schema.interface[interface_name].type[function_type].functions[function_name]==nil) then 
    result = false
    error_message[function_name] ="function " .. function_name.." has not been found in schema"
    return result, error_message
  end
  result, error_message[function_name] = self:CheckFunctionParams(interface_name, function_name, function_type, user_data)

  return result, error_message 
end


function module.mt.__index:Validate(function_id, function_type, user_data)
  local result = true
  local error_message = {}
  result, error_message = self:Compare(function_id, function_type, user_data)
  return result, errorMsgToString(error_message)
end

return module
