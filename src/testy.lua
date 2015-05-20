#!/usr/bin/env lua

-- Simple unit testing script for Lua.
-- Loads and inspects Lua files for local variables (functions) in the
-- main chunk that start with `test_` and calls them. The `assert`
-- function is monkey-patched to be non-fatal inside of those test
-- functions and provide test statistics at the end.


-- you might want to customize those variables:
local prefix = "test_" -- the prefix of test functions to look for
local pass_char, fail_char = ".", "X" -- output for passed/failed tests
local max_line = 72 -- where to wrap test output in the terminal
local fh = io.stderr -- file handle to print test output to


-- but those are off limits:
local files, chunks, do_recursive = {}, {}, false
local tests, test_functions = {}, {}
local n_tests, n_passed, n_errors = 0, 0, 0
local cursor_pos = 0
local thischunk = debug.getinfo( 1, "f" ).func


-- update test statistics
local function testy_update( finfo, cinfo, ok, ... )
  n_tests = n_tests + 1
  fh:write( ok and pass_char or fail_char )
  cursor_pos = (cursor_pos + 1) % max_line
  if cursor_pos == 0 then
    fh:write( "\n" )
  end
  fh:flush()
  if ok then
    n_passed = n_passed + 1
    return ok, ...
  else
    local fail = {
      no = n_tests,
      line = cinfo.currentline,
      reason = (...) ~= nil and tostring( (...) ) or nil
    }
    finfo[ #finfo+1 ] = fail
  end
end


local assert = assert

-- we provide a monkey-patched `assert` function that doesn't kill the
-- process when called from within the test functions and updates the
-- test statistics
local function _G_assert( ok, ... )
  -- check whether we are in a test_ function and act accordingly
  local info = debug.getinfo( 2, "fl" )
  local finfo = test_functions[ info.func or false ]
  if finfo then
    return testy_update( finfo, info, ok, ... )
  else
    return assert( ok, ... )
  end
end


-- assert-like function that updates test statistics and works if any
-- test function is on the call stack
local function _G_testy_assert( ok, ... )
  local info, i, finfo = debug.getinfo( 2, "fl" ), 3
  while info do
    if info.func == thischunk then break end
    finfo = test_functions[ info.func or false ]
    if finfo then break end
    info, i = debug.getinfo( i, "fl" ), i+1
  end
  if finfo then
    return testy_update( finfo, info, ok, ... )
  else
    error( "call to 'testy_assert' function outside of tests", 2 )
  end
end


-- print final tests statistics and exit with a non-zero status if
-- there were failed tests
local function final_report()
  if cursor_pos ~= 0 then
    fh:write( "\n" )
  end
  fh:write( n_tests, " tests (", n_passed, " ok, ", n_tests-n_passed,
            " failed, ", n_errors, " errors)\n" )
  fh:flush()
  if n_tests ~= n_passed or n_errors > 0 then
    os.exit( 1, true )
  end
end


-- from within the return hook find the stack level of the main chunk
-- that should contain the test functions
local function main_chunk( lvl )
  lvl = lvl+1 -- skip stack level of this function
  local info, i = debug.getinfo( lvl, "Sf" ), lvl+2
  if not info or info.what ~= "main" or info.func == thischunk then
    return false
  end
  if not do_recursive then
    info = debug.getinfo( lvl+1, "Sf" )
    while info and info.func ~= thischunk do
      if info.what == "main" then
        return false
      end
      info, i = debug.getinfo( i, "Sf" ), i+1
    end
  end
  return true
end


-- The return hook which collects local test functions from the main
-- chunk loaded by this script (or any main chunk if -r is in effect).
-- This function is currently unused, see below! XXX
local function return_hook( event )
  if event ~= "tail return" and main_chunk( 2 ) then
    local source = debug.getinfo( 2, "S" ).short_src
    local i, name, value = 2, debug.getlocal( 2, 1 )
    while name do
      if #name >= #prefix and
         type( value ) == "function" and
         name:sub( 1, #prefix ) == prefix then
        local caption = name:sub( #prefix+1 ):gsub( "_", " " )
        local tdata = {
          caption = caption,
          name = name,
          func = value,
          source = source,
        }
        tests[ #tests+1 ] = tdata
        test_functions[ value ] = tdata
      end
      i, name, value = i+1, debug.getlocal( 2, i )
    end
  end
end


-- only needed because we collect the locals in a line_hook XXX
local locals = {}

-- The return hook doesn't work as expected in PUC-Rio Lua (the values
-- of local variables are garbled), so we additionally use a line
-- hook. This is a lot more expensive, since we query the local
-- variables every line and keep only the last set, but you probably
-- don't do much computation in main chunks of modules anyway ... XXX
local function line_ret_hook( event, no )
  if event ~= "tail_return" and main_chunk( 2 ) then
    local info = debug.getinfo( 2, "Sf" )
    if event == "line" then
      local locs = {}
      local i, name, value = 2, debug.getlocal( 2, 1 )
      while name do
        if #name >= #prefix and
           type( value ) == "function" and
           name:sub( 1, #prefix ) == prefix then
          local caption = name:sub( #prefix+1 ):gsub( "_", " " )
          local tdata = {
            caption = caption,
            name = name,
            func = value,
            source = info.short_src,
          }
          locs[ #locs+1 ] = tdata
        end
        i, name, value = i+1, debug.getlocal( 2, i )
      end
      locals[ info.func ] = locs
    else -- return hook
      for _,tdata in ipairs( locals[ info.func ] or {} ) do
        tests[ #tests+1 ] = tdata
        test_functions[ tdata.func ] = tdata
      end
    end
  end
end


-- When using the line hook to collect local variables under some
-- circumstances the last local isn't picked up when the definition
-- is the last statement in the chunk. We try to append an additional
-- statement (`return`) to fix that (or revert to the normal source if
-- compilation fails with this modification). XXX
local function testy_loadfile( fname )
  local f, msg = io.open( fname, "rb" )
  if not f then
    return nil, msg
  end
  local s = f:read( "*a" )
  if not s then
    return nil, "input/ouput error"
  end
  s = s:gsub( "^#[^\n]*", "") .. "\nreturn\n"
  local c, msg = (loadstring or load)( s, "@"..fname )
  if c then
    return c
  else
    return loadfile( fname )
  end
end


-- process command line arguments
for i,a in ipairs( _G.arg ) do
  if a == "-r" then
    do_recursive = true
  else
    files[ #files+1 ] = a
  end
  _G.arg[ i ] = nil
end

-- rule out syntax errors (and missing files)
for i,f in ipairs( files ) do
  chunks[ i ] = assert( testy_loadfile( f ) ) -- XXX
end

-- load lua files and collect tests via a return hook
for i,c in ipairs( chunks ) do
  _G.arg[ 0 ] = files[ i ]
  _G.assert = _G_assert
  _G.testy_assert = _G_testy_assert
  --debug.sethook( return_hook, "r" )
  debug.sethook( line_ret_hook, "lr" ) -- XXX
  -- pcall chunk (simulate a searchers call for modules)
  local ok, msg = pcall( c, "module.test", files[ i ] )
  debug.sethook()
  if not ok then
    n_errors = n_errors + 1
    fh:write( "[ERROR] loading '", files[ i ], "' failed:",
              msg, "\n" )
    fh:flush()
  end
end

-- actually run the tests
for i,t in ipairs( tests ) do
  if cursor_pos ~= 0 then
    fh:write( "\n" )
    cursor_pos = 0
  end
  local headerlen = #t.caption + #t.source + 8
  fh:write( t.caption, " ('", t.source, "')" )
  if headerlen >= max_line then
    fh:write( "\n" )
    cursor_pos = 0
  else
    fh:write( "   " )
    cursor_pos = headerlen
  end
  fh:flush()
  _G.assert = _G_assert
  _G.testy_assert = _G_testy_assert
  local ok, msg = xpcall( t.func, debug.traceback )
  if cursor_pos ~= 0 then
    fh:write( "\n" )
    cursor_pos = 0
  end
  if not ok then
    n_errors = n_errors + 1
    fh:write( "  [ERROR] test function '", t.name, "' died:\n  ",
              msg:gsub( "\n", "\n  " ), "\n" )
  else
    for _,f in ipairs( t ) do
      fh:write( "  [FAIL] ", t.source, ":", f.line, ": in function '",
                t.name, "'\n" )
      if f.reason then
        fh:write( "    reason: \"", f.reason, "\"\n" )
      end
    end
  end
  fh:flush()
end

-- output final statistics
final_report()

