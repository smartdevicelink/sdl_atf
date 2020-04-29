--- Module which build ATF configuration from configuration pieces
--
-- *Dependencies:* `config_builder`
--
-- *Globals:* none
-- @copyright [Ford Motor Company](https://smartdevicelink.com/partners/ford/) and [SmartDeviceLink Consortium](https://smartdevicelink.com/consortium/)
-- @license <https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE>

local config_builder = require('config_builder')

local function getConfigFilesList(folderPath)
	local command = "ls " .. folderPath
	local fileSuffix = "_config"
	local fileExt =  ".lua"
	local mask = "%" .. fileSuffix .. fileExt .. "$"
	local suffixLength = (-1) * #fileExt - 1

	local resultList = {}
	for fileName in io.popen(command):lines() do
		if string.find(fileName, mask) then
			table.insert(resultList, string.sub(fileName, 1, suffixLength))
		end
	end
	if not next(resultList) then
		error("ConfigLoader: Configuration folder " .. folderPath .. " is not found")
	end
	return resultList
end

local function buildConfiguration(base, environment)
	local configurationFolderPath = "./modules/configuration"
	if environment then
		configurationFolderPath = configurationFolderPath .. "/" .. environment
	end

	local configurationBuilder = config_builder.ConfigurationBuilder(base, environment)

	for _, configurationFileName in ipairs(getConfigFilesList(configurationFolderPath)) do
		configurationBuilder:addConfiguration(configurationFileName)
	end

	configurationBuilder:buildConfiguration()
end

local config = {}

buildConfiguration(config)

if specific_environment then
	buildConfiguration(config, specific_environment)
	specific_environment = nil
end

return config
