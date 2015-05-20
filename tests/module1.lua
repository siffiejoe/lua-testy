local M = {}

local mod2 = require( "module2" )

function M.func3()
  return mod2.func1()
end

local function test_func3()
  local function my_test()
    testy_assert( M.func3() == 1 )
  end
  my_test()
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
  assert( M.func3() == 2 )
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
  assert( M.func3() == 1 )
end

return M

