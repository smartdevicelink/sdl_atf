project = 'ATF'
title = 'ATF SW Detail Design documentation'
description = [[
# Automated Test Framework (ATF) system
ATF is a C++/Lua framework for SDL automated black-box testing.
It provides high- and low-level API for mobile applications and/or HMIs emulation.

For High-level information, please follow [ATF SW Architecture Document](https://smartdevicelink.com/en/guides/pull_request/93dee199f30303b4b26ec9a852c1f5261ff0735d/atf/table-of-contents/)

For Detail design information, please follow related SDD.

## LICENSE
The code is copyright [Ford Motor Company](https://github.com/smartdevicelink/sdl_core/blob/master/LICENSE).
]]
format='discount'
style='!pale'
backtick_references=true
sort = false
kind_names={topic='SDD'}

-- Output
dir='../docs/html'
-- Input Lua files
file = {
	'../modules/',
	exclude = {'../modules/atf/stdlib/',
			   '../modules/json4lua/',
			  }
	}
-- ATF usage examples
examples = {  '../examples' }
-- Input markdown files with SDDs
topics = { '../modules/docs' }
