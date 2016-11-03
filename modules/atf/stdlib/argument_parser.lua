local std = require "atf.stdlib.std"
local table = require "atf.stdlib.std.table"

local exit_codes = require('exit_codes')

local validOptList = { }
local errors = {}

local usage = [[
ATF 2.2

Usage: ./start.sh [OPTIONS] script.lua

]]

local help = {}

local fotter = [[
-v,--version display version information, then exit
-h,--help display this help, then exit
]]

local version = "ATF 2.2"

local optparser = std.optparse [[
ATF 2.2
Additional lines of text to show when the --version
option is passed.

Several lines or paragraphs are permitted.

Usage: atf cmd_test.lua [OPTIONS] script.lua
]]

local module = {
  mt = { __index = { } } ,
  RequiredArgument = 1,
  OptionalArgument = 2,
  NoArgument = 3
}

local function errmsg (msg)
  local prog = "ATF 2.2"
  -- Ensure final period.
  if msg:match ("%.$") == nil then msg = msg .. "." end
  print (prog .. ": error: " .. msg .. "\n")
  print (prog .. ": Try '" .. prog .. " --help' for help.")
  quit(exit_codes.wrong_arg)
end

local function checkReqOpt(self, arg, val)
  if val:sub (1, 1) == "-" then
    errmsg ("Option '" .. arg .. "' requires an argument.")
    quit(exit_codes.wrong_arg)
  else
    validOptList[self[arg].key] = val
  end
end

function module.getopt(argv, opts)
  local res = {}
  if (argv[1] == nil) then module.PrintUsage() end

  optparser:on ({"--"}, optparser.finished)
  optparser:on ({"-?"}, optparser.optional,module.PrintUsage)
  optparser:on ({"-h","--help"}, optparser.optional,module.PrintUsage)
  optparser:on ({"-v","--version"}, optparser.optional,module.PrintVersion)

  local function parse(argv)
    return optparser:parse (argv)
  end

  local unrecognized_options,options = parse(argv)

  res = table.merge(validOptList, options)
  for i = 1 , #unrecognized_options do
    if (unrecognized_options[i]:sub(1,1)~= "-") then
      table.insert(res,unrecognized_options[i])
    else
      errmsg("undefined option: '" .. unrecognized_options[i] .. "'")
      return nil
    end
  end

  setmetatable(res, module.mt)

  return res
end
function module.declare_opt (shortname, longname, argument, description)
  local arg = ''
  if (argument == module.RequiredArgument) then
    optparser:on (table.pack(shortname, longname), optparser.required,checkReqOpt)
  elseif (argument == module.OptionalArgument) then
    optparser:on (table.pack(shortname, longname), optparser.optional)
  else
    optparser:on (table.pack(shortname, longname), optparser.flag)
  end

  arg = string.format(" %s", description or 'value')
  if (shortname:len() > 0 and longname:len() > 0) then
    table.insert(help, shortname .. ',' .. longname .. arg )
  else
    table.insert(help, shortname .. longname .. arg )
  end

end
function module.declare_short_opt(shortname, argument, description)
  module.declare_opt (shortname, '' , argument, description)
end
function module.declare_long_opt(longname, argument, description)
  module.declare_opt('' ,longname , argument, description)
end
function module.PrintUsage()
  local _usage = usage
  for _, opt in ipairs(help) do
    _usage = _usage .. opt .. '\n' .. ' '
  end

  _usage = _usage .. '\n' ..' ' .. fotter
  print(_usage)
  quit()
end
function module.PrintVersion()
  print(version)
  quit()
end

return module
