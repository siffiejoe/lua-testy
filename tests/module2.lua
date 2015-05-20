local M = {}

function M.func1()
  return 1
end


local function test_func1()
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 2 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 2, "that is unexpected!" )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
  assert( M.func1() == 1 )
end

function M.func2()
  error( "argh!" )
end

local function test_func2_with_a_very_long_caption_so_that_the_line_is_full_and_overflows()
  assert( 1 == 1 )
  assert( 1 == 1 )
  assert( 1 == 1 )
  assert( 1 == 1 )
  assert( 1 == 1 )
  assert( 1 == 1 )
  assert( M.func2() == 1 )
  assert( 1 == 1 )
end

return M

