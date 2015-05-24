local assert = assert

if _VERSION == "Lua 5.1" then
  module( "module3" )
else
  local _M = {}
  package.loaded[ "module3" ] = _M
  _ENV = _M
end

function func4()
  return 4
end

local function test_func4()
  assert( func4() == 4 )
end

