local validator = require("schema_validation")

local json_hmi_tbl = { numTicks = 7, position = 6, sliderHeader ="sliderHeader",
  sliderFooter =
  {
    "sliderFooter1",
    "sliderFooter2",
    "sliderFooter3",
    "sliderFooter4",
    "sliderFooter5",
    "sliderFooter6",
    "sliderFooter7",
  },
  timeout = 3000,
  appID = 1
}

local json_mob_tbl = {success = true, resultCode = {"SUCCESS"}}

local _res, _err = validator.validate_hmi_request('UI.Slider', json_hmi_tbl)
if _res then
  print("validate_hmi_request:"..tostring(_res))
else
  print("validate_hmi_request:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.validate_mobile_response('Slider',json_mob_tbl,true)
if _res then
  print("validate_mobile_response:"..tostring(_res))
else
  print("validate_mobile_response:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.validate_mobile_response( 'Slider',{ success = 'true', resultCode = {"SUCCESS"} },true)
if _res then
  print("validate_mobile_response:"..tostring(_res))
else
  print("validate_mobile_response:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.validate_mobile_response( "WrongFunctionName", { success = false, resultCode = "INVALID_DATA", info = nil })
if _res then
  print("validate_mobile_response with \"WrongFuntionName\":"..tostring(_res))
else
  print("validate_mobile_response with \"WrongFuntionName\":"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.validate_hmi_notification( 'BasicCommunication.OnSystemRequest', { requestType = {"PROPRIETARY"}})
if _res then
  print("validate_hmi_notification:"..tostring(_res))
else
  print("validate_hmi_notification:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.validate_hmi_notification( 'BasicCommunication.OnSystemRequest', { urlSchema = "default", fileName = "fileName"}, true)
if _res then
  print("validate_hmi_notification:"..tostring(_res))
else
  print("validate_hmi_notification:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.validate_mobile_notification( "OnHMIStatus", {hmiLevel = "FULL"})
if _res then
  print("validate_modile_notification:"..tostring(_res))
else
  print("validate_mobile_notification:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.json_validate(json_mob_tbl, {resultCode = {"SUCCESS"} })
if _res then
  print("json_validate:"..tostring(_res))
else
  print("json_validate:"..tostring(_res).." ==> ".._err)
end

_res, _err = validator.json_validate(json_mob_tbl, { success = 'true', resultCode = {"SUCCESS"} } )
if _res then
  print("json_validate:"..tostring(_res))
else
  print("json_validate:"..tostring(_res).." ==> ".._err)
end

local _res, _err = validator.validate_mobile_request('PerformInteraction',
  { initialText = "initialText",
    initialPrompt = {{text = "initialPrompt", type = "TEXT"}},
    interactionMode = "MANUAL_ONLY",
    interactionChoiceSetIDList = {1},
    helpPrompt = {{text = "helpPrompt", type = "TEXT"}},
    interactionLayout = "KEYBOARD"
  })
if _res then
  print("validate_hmi_request:"..tostring(_res))
else
  print("validate_hmi_request:"..tostring(_res).." ==> ".._err)
end

quit()
