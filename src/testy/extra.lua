local assert = assert
local type = assert( type )
local select = assert( select )
local pairs = assert( pairs )
local pcall = assert( pcall )
local error = assert( error )
local rawequal = assert( rawequal )
local tostring = assert( tostring )
local setmetatable = assert( setmetatable )
local require = assert( require )
local string = require( "string" )
local s_sub = assert( string.sub )
local s_byte = assert( string.byte )
local s_format = assert( string.format )
local s_match = assert( string.match )
local s_gsub = assert( string.gsub )
local table = require( "table" )
local t_concat = assert( table.concat )
local t_unpack = assert( table.unpack or unpack )
local coroutine = require( "coroutine" )
local co_create = assert( coroutine.create )
local co_resume = assert( coroutine.resume )
local co_status = assert( coroutine.status )
local debug = require( "debug" )
local d_getinfo = assert( debug.getinfo )
local d_getlocal = assert( debug.getlocal )
local d_getmetatable = assert( debug.getmetatable )


-- the module table
local M = {}


-- keep track of functions for customized stack traces
local F = setmetatable( {}, { __mode = "k" } )

-- distinguish between non-existent locals and nil-valued locals!
local NIL = setmetatable( {}, {
  __tostring = function() return "nil" end
} )


-- used to handle varargs without a tail call (tail calls mess with
-- call frames, and we need those for our stack traces!)
local function notail( ... )
  return ...
end


-- raise a type error similar to luaL_typeerror()
local function type_error( fname, n, expected, v, idx )
  error( s_format( "bad argument #%d to '%s' (%s expected, got %s)",
                   fname, n, expected, type( v ) ), (idx or 2)-1 )
end


-- just for internal testing ...
local function assert_not( ok, ... )
  return testy_assert( not ok, ... )
end


--[[ XXX
-- output is important for this library. uncomment this section
-- to let all tests fail and force output of failure messages
local function assert( ok, ... )
  return testy_assert( not ok, ... )
end
local function assert_not( ok, ... )
  return testy_assert( ok, ... )
end
--]]


local smax_len, lmax_len = 25, 45
local function abbrev( s, max_len )
  if #s > max_len then
    s = s_sub( s, 1, max_len-9 ).."..."..s_sub( s, -6 )
  end
  return s
end


local function test_abbrev()
  local s = "abcdefghijklmnopqrstuvwxyz"
  assert( #abbrev( s, smax_len ) <= smax_len )
  assert( #abbrev( s, lmax_len ) <= lmax_len )
  assert( abbrev( s, smax_len ):match( "%.%.%.uvwxyz$" ) )
  assert( abbrev( s, lmax_len ) == s )
end


local escape
do
  local escape_map = {
    ["\a"] = "\\a",
    ["\b"] = "\\b",
    ["\f"] = "\\f",
    ["\n"] = "\\n",
    ["\r"] = "\\r",
    ["\t"] = "\\t",
    ["\v"] = "\\v",
    ["\\"] = "\\\\",
    ['"'] = '\\"',
  }

  local patt = "([^ !#$%%&'%(%)%*%+,%-%./%w:;<=>%?@%[%]^_`%{|%}~])(%d?)"

  local function cb( c, f )
    local r = escape_map[ c ]
    if r then
      return r..f
    else
      return s_format( f=="" and "\\%d" or "\\%03d", s_byte( c ) )..f
    end
  end

  function escape( v, max_len )
    if type( v ) == "string" then
      return abbrev( '"'..s_gsub( v, patt, cb )..'"', max_len )
    else
      return abbrev( tostring( v ), max_len )
    end
  end
end


local function test_escape()
  local s1 = "\0\0000\1\0010\2\3\128\255"
  local s2 = "\a\b\f\n\r\t\v\\\"'"
  local s3 = "^!$%&/()[]{}=?`*+~'#q<>|,;.:-_"
  local s4 = "abczABCZ01239"
  local s5 = ""
  for i = 1, 255 do s5 = s5..string.char( i ) end
  assert( escape( s1, 100 ) == [["\0\0000\1\0010\2\3\128\255"]] )
  assert( escape( s2, 100 ) == [["\a\b\f\n\r\t\v\\\"'"]] )
  assert( escape( s3, 100 ) == '"'..s3..'"' )
  assert( escape( s4, 100 ) == '"'..s4..'"' )
  assert( not escape( s5, 500 ):match( "%c" ) )
end


-- generate a customized stack trace to indicate where the return
-- value of a deeply nested test expression originated
local function context()
  local t, i, info = {}, 2, d_getinfo( 2, "f" )
  while info do
    local s = F[ info.func ]
    if s then
      local locals = {}
      local j, name, value = 1, d_getlocal( i, 1 )
      while name ~= nil do
        if value == nil then value = NIL end
        locals[ j.."" ] = value
        locals[ name ] = value
        j = j + 1
        name, value = d_getlocal( i, j )
      end
      t[ #t+1 ] = s_gsub( s, "%$%{([!@]?)([%w_]+)%}", function( q, id )
        local v = locals[ id ]
        if v == nil then
          return '?'
        elseif q == "!" then
          return v -- unescaped; v must be a string!
        elseif q == "@" then
          return escape( v, lmax_len )
        else
          return escape( v, smax_len )
        end
      end )
    end
    i = i + 1
    info = d_getinfo( i, "f" )
  end
  for _ in pairs( t ) do
    return t_concat( t, "\n\t" )
  end
end


-- return a function that is equivalent to the passed function f if
-- called with two or more arguments, but returns a partially applied
-- f when called with only one (the one argument is bound to the
-- *second* parameter in this case!)
local function curry_flip( f )
  return function( x, ... )
    if select( '#', ... ) > 0 then
      return f( x, ... )
    else
      return function( y, ... )
        return f( y, x, ... ) -- reorder arguments!
      end
    end
  end
end


local is_
do
  local function makeset( t )
    local nt = {}
    for _,v in pairs( t ) do
      nt[ v ] = true
    end
    return nt
  end

  local keywords = makeset{
    "and", "break", "do", "else", "elseif", "end",
    "false", "for", "function", "goto", "if", "in",
    "local", "nil", "not", "or", "repeat", "return",
    "then", "true", "until", "while"
  }

  local function field_selector( v )
    if type( v ) == "string" and
       s_match( v, "^[%a_][%w_]*$" ) and
       not keywords[ v ] then
      return "."..abbrev( v, smax_len )
    else
      return "["..escape( v, smax_len ).."]"
    end
  end

  local function eq_context( v, x, y, sel )
    return v, context()
  end
  F[ eq_context ] = "${!4} is ${3}?  (${!4}: ${2})"

  local function pred_context( x, y, sel )
    local ok, msg = y( x )
    return ok, msg or context()
  end
  F[ pred_context ] = "f(${!3})?  (${!3}: ${1})"

  local function patt_context( x, y, sel )
    return true, context()
  end
  F[ patt_context ] = "${!3} is like ${2}?"

  function is_( x, y, sel, pskip )
    if x == y then
      return eq_context( true, x, y, sel )
    else
      local t = type( y )
      if t == "function" then
        if pskip then
          local ok, msg = y( x )
          return ok, msg or context()
        else
          return pred_context( x, y, sel )
        end
      elseif t == "table" and type( x ) == "table" then
        for k,v in pairs( y ) do
          local ok, msg = is_( x[ k ], v, sel..field_selector( k ) )
          if not ok then return false, msg end
        end
        return patt_context( x, y, sel )
      elseif t == "number" and y ~= y and x ~= x then
        return eq_context( true, x, y, sel )
      end
      return eq_context( false, x, y, sel )
    end
  end
  M.is = curry_flip( function( x, y )
    return is_( x, y, "x" )
  end )
end


local function test_is()
  assert( M.is( 3, 3 ) )
  assert( M.is( 3 )( 3 ) )
  assert_not( M.is( 3, 4 ) )
  assert_not( M.is( 4 )( 3 ) )
  assert( M.is( 3, M.is_number ) )
  assert( M.is( M.is_number )( 3 ) )
  assert( M.is( M.is_number )( M.is_number ) )
  assert_not( M.is( 3 )( M.is_number ) )
  assert_not( M.is( "3", M.is_number ) )
  assert_not( M.is( M.is_number )( "3" ) )
  assert( M.is( 0/0, 0/0 ) )
  assert( M.is( 0/0, -(0/0) ) )
  assert_not( M.is( 0/0, 0 ) )
  assert_not( M.is( 0, 0/0 ) )
  assert( M.is( {a=1,b=2,c=3}, {a=1,b=2} ) )
  assert( M.is( {a=1,b=2} )( {a=1,b=2,c=3} ) )
  assert_not( M.is( {a=1,b=2}, {a=1,b=2,c=3} ) )
  assert_not( M.is( {a=1,b=2}, {a=1,c=3} ) )
  assert_not( M.is( {a=1,b=2,c=3} )( {a=1,b=2} ) )
  assert( M.is( {a=1,b=2}, {a=M.is_lt(2),b=2} ) )
  assert_not( M.is( {a=1,b=2}, {a=M.is_gt(2),b=2} ) )
  assert( M.is( {a={b=1},c=2}, {a={b=1},c=2} ) )
  assert( M.is( {a={1,2,3},b=2}, {a={1},b=2} ) )
  assert_not( M.is( {a={1,2},b=2}, {a={1,2,3},b=2} ) )
  assert_not( M.is( {a={1,2},b=2}, {a={1,3},b=2} ) )
end


do
  local function is_t( x, t )
    return type( x ) == t, context()
  end
  F[ is_t ] = "type(x) == ${2}?  (x: ${1})"
  local is_type = curry_flip( is_t )

  local types = {
    "nil", "boolean", "number", "string", "function",
    "userdata", "thread", "table", "cdata"
  }
  for i = 1, #types do
    M[ "is_"..types[ i ] ] = is_type( types[ i ] )
  end
end


local function test_is__type()
  assert( M.is_nil( nil ) )
  assert_not( M.is_nil( 1 ) )
  assert( M.is_boolean( true ) )
  assert_not( M.is_boolean( nil ) )
  assert( M.is_number( 3 ) )
  assert_not( M.is_number( "3" ) )
  assert( M.is_string( "3" ) )
  assert_not( M.is_string( 3 ) )
  assert( M.is_function( function() end ) )
  assert_not( M.is_function( false ) )
  assert( M.is_userdata( io.stdout ) )
  assert_not( M.is_userdata( {} ) )
  assert( M.is_thread( coroutine.create( function() end ) ) )
  assert_not( M.is_thread( function() end ) )
  assert( M.is_table( {} ) )
  assert_not( M.is_table( "" ) )
  do
    local ok, ffi = pcall( require, "ffi" )
    if ok then
      local ctype = ffi.metatype( "struct { int number; }", {} )
      local cdata = ffi.new( ctype )
      assert( M.is_cdata( ctype ) )
      assert( M.is_cdata( cdata ) )
    end
  end
  assert_not( M.is_cdata( io.stdout ) )
end


do
  local function is_false( x )
    return not x, context()
  end
  F[ is_false ] = "x == false or x == nil? (x: ${1})"
  M.is_false = is_false
end


local function test_is__false()
  assert( M.is_false( nil ) )
  assert( M.is_false( false ) )
  assert_not( M.is_false( 1 ) )
  assert_not( M.is_false( {} ) )
  assert_not( M.is_false( true ) )
  assert_not( M.is_false( "" ) )
end


do
  local function is_true( x )
    return not not x, context()
  end
  F[ is_true ] = "x ~= false and x ~= nil? (x: ${1})"
  M.is_true = is_true
end


local function test_is__true()
  assert( M.is_true( 1 ) )
  assert( M.is_true( {} ) )
  assert( M.is_true( true ) )
  assert( M.is_true( "" ) )
  assert_not( M.is_true( false ) )
  assert_not( M.is_true( nil ) )
end


do
  local function is_len( x, l )
    local len = #x
    return len == l, context()
  end
  F[ is_len ] = "#x == ${2}?  (x: ${1}, #x: ${len})"
  M.is_len = curry_flip( is_len )
end


local function test_is__len()
  assert( M.is_len( {}, 0 ) )
  assert_not( M.is_len( { 1 }, 0 ) )
  assert( M.is_len( "", 0 ) )
  assert_not( M.is_len( "a", 0 ) )
  assert( M.is_len( { 1, 2, 3 }, 3 ) )
  assert( M.is_len( "abc", 3 ) )
  assert( M.is_len( 0 )( {} ) )
  assert( M.is_len( 0 )( "" ) )
  assert( M.is_len( 3 )( { 1, 2, 3 } ) )
  assert( M.is_len( 3 )( "abc" ) )
end


do
  local function is_like( x, p )
    return type( x ) == "string" and not not s_match( x, p ),
           context()
  end
  F[ is_like ] = "x:match(${2})?  (x: ${1})"
  M.is_like = curry_flip( is_like )
end


local function test_is__like()
  assert( M.is_like( "abc", "^a" ) )
  assert( M.is_like( "abc", "a" ) )
  assert( M.is_like( "abc", "c$" ) )
  assert( M.is_like( "^a" )( "abc" ) )
  assert( M.is_like( "c$" )( "abc" ) )
  assert_not( M.is_like( "abc", "d" ) )
  assert_not( M.is_like( "abc" )( "a" ) )
end


do
  local function metafield( obj, name )
    local mt = d_getmetatable( obj )
    if type( mt ) == "table" then
      return mt[ name ]
    end
  end

  local function is_eq_( x, y, cache )
    if x == y then
      return true
    else
      local tx, ty = type( x ), type( y )
      if tx == ty then
        if tx == "number" and x ~= x and y ~= y then
          return true
        elseif tx == "table" then
          if metafield( x, "__eq" ) == nil and
             metafield( y, "__eq" ) == nil then
            -- no __eq, so we can do deep (recursive) comparison
            if cache[ x ] == y then
              return true
            elseif cache[ x ] == nil then
              cache[ x ], cache[ y ] = y, x
              if not is_eq_( d_getmetatable( x ),
                             d_getmetatable( y ), cache ) then
                return false
              end
              for k,v in pairs( x ) do
                if not is_eq_( v, y[ k ], cache ) then return false end
              end
              for k,v in pairs( y ) do
                if not is_eq_( x[ k ], v, cache ) then return false end
              end
              return true
            end
          end
        end
      end
    end
    return false
  end

  local function is_eq( x, y )
    return is_eq_( x, y, {} ), context()
  end
  F[ is_eq ] = "x == ${2}?  (x: ${1})"
  M.is_eq = curry_flip( is_eq )
end


local function test_is__eq()
  assert( M.is_eq( 3, 3 ) )
  assert( M.is_eq( 3 )( 3 ) )
  assert_not( M.is_eq( 3, 4 ) )
  assert_not( M.is_eq( 4 )( 3 ) )
  local t = {}
  assert( M.is_eq( t, t ) )
  assert( M.is_eq( { 1 }, { 1 } ) )
  assert_not( M.is_eq( { 1 }, {} ) )
  assert_not( M.is_eq( {}, { 1 } ) )
  assert( M.is_eq( 0/0, 0/0 ) )
  assert( M.is_eq( 0/0, -(0/0) ) )
  assert_not( M.is_eq( 0/0, 0 ) )
  assert_not( M.is_eq( 0, 0/0 ) )
  local a, b = {}, {}
  a.x, b.x = b, a
  assert( M.is_eq( a, b ) )
  assert( M.is_eq( b, a ) )
  setmetatable( a, t )
  assert_not( M.is_eq( a, b ) )
  assert_not( M.is_eq( b, a ) )
  setmetatable( b, {} )
  assert( M.is_eq( a, b ) )
  assert( M.is_eq( b, a ) )
  b.y = 1
  assert_not( M.is_eq( a, b ) )
  assert_not( M.is_eq( b, a ) )
  local c, d = { x = {} }, {}
  d.x = { y = d }
  assert_not( M.is_eq( c, d ) )
  assert_not( M.is_eq( d, c ) )
  local meta = {
    __eq = function( x, y ) return x.x == y.x end
  }
  local e = setmetatable( { x = 1, y = 2 }, meta )
  local f = setmetatable( { x = 1 }, meta )
  assert( M.is_eq( e, f ) )
  assert( M.is_eq( f, e ) )
  local g, h = { x = e }, { x = f }
  assert( M.is_eq( g, h ) )
  assert( M.is_eq( h, g ) )
  local i, j = { e, 1 }, { f }
  assert_not( M.is_eq( i, j ) )
  assert_not( M.is_eq( j, i ) )
end


do
  local function is_raweq( x, y )
    if x ~= x and y ~= y then
      return true, context()
    else
      return rawequal( x, y ), context()
    end
  end
  F[ is_raweq ] = "rawequal(x, ${2})? (x: ${1})"
  M.is_raweq = curry_flip( is_raweq )
end


local function test_is__raweq()
  assert( M.is_raweq( 3, 3 ) )
  assert( M.is_raweq( 3 )( 3 ) )
  assert_not( M.is_raweq( 3, 4 ) )
  assert_not( M.is_raweq( 4 )( 3 ) )
  assert( M.is_raweq( 0/0, 0/0 ) )
  assert( M.is_raweq( 0/0, -(0/0) ) )
  assert_not( M.is_raweq( 0/0, 0 ) )
  assert_not( M.is_raweq( 0, 0/0 ) )
  local a, b = {}, {}
  assert( M.is_raweq( a, a ) )
  assert_not( M.is_raweq( a, b ) )
  assert_not( M.is_raweq( b, a ) )
  local meta = {
    __eq = function( x, y ) return x.x == y.x end
  }
  local c = setmetatable( { x = 1 }, meta )
  local d = setmetatable( { x = 1 }, meta )
  assert( M.is_raweq( c, c ) )
  assert_not( M.is_raweq( c, d ) )
  assert_not( M.is_raweq( d, c ) )
end


do
  local function is_gt( x, y )
    return x > y, context()
  end
  F[ is_gt ] = "x > ${2}?  (x: ${1})"
  M.is_gt = curry_flip( is_gt )
end


local function test_is__gt()
  assert( M.is_gt( 4, 3 ) )
  assert( M.is_gt( 3 )( 4 ) )
  assert_not( M.is_gt( 3, 4 ) )
  assert_not( M.is_gt( 3, 3 ) )
  assert_not( M.is_gt( 4 )( 3 ) )
end


do
  local function is_lt( x, y )
    return x < y, context()
  end
  F[ is_lt ] = "x < ${2}?  (x: ${1})"
  M.is_lt = curry_flip( is_lt )
end


local function test_is__lt()
  assert( M.is_lt( 3, 4 ) )
  assert( M.is_lt( 4 )( 3 ) )
  assert_not( M.is_lt( 4, 3 ) )
  assert_not( M.is_lt( 3, 3 ) )
  assert_not( M.is_lt( 3 )( 4 ) )
end


do
  local function is_ge( x, y )
    return x >= y, context()
  end
  F[ is_ge ] = "x >= ${2}?  (x: ${1})"
  M.is_ge = curry_flip( is_ge )
end


local function test_is__ge()
  assert( M.is_ge( 4, 3 ) )
  assert( M.is_ge( 3 )( 4 ) )
  assert( M.is_ge( 3, 3 ) )
  assert_not( M.is_ge( 3, 4 ) )
  assert_not( M.is_ge( 4 )( 3 ) )
end


do
  local function is_le( x, y )
    return x <= y, context()
  end
  F[ is_le ] = "x <= ${2}?  (x: ${1})"
  M.is_le = curry_flip( is_le )
end


local function test_is__le()
  assert( M.is_le( 3, 4 ) )
  assert( M.is_le( 4 )( 3 ) )
  assert( M.is_le( 3, 3 ) )
  assert_not( M.is_le( 4, 3 ) )
  assert_not( M.is_le( 3 )( 4 ) )
end


function M.any( ... )
  local n, preds = select( '#', ... ), { ... }
  for i = 1, n do
    local y = preds[ i ]
    preds[ i ] = function( ... )
      if type( y ) == "function" and (...) ~= y then
        return y( ... )
      else
        return is_( ..., y, "x", true )
      end
    end
  end

  local function check( ... )
    for i = 1, n do
      local ok, msg = preds[ i ]( ... )
      if ok then return true, msg end
    end
    return false, context()
  end
  F[ check ] = "any(...)?"
  return check
end


local function test_any()
  assert_not( M.any()( 1 ) )
  assert( M.any( M.is_number )( 1 ) )
  assert_not( M.any( M.is_string )( 1 ) )
  assert( M.any( M.is_number, M.is_string )( 1 ) )
  assert_not( M.any( M.is_string, M.is_table )( 1 ) )
  assert( M.any( M.resp( 1, 1 ) )( 1, 1 ) )
end


function M.all( ... )
  local n, preds = select( '#', ... ), { ... }
  for i = 1, n do
    local y = preds[ i ]
    preds[ i ] = function( ... )
      if type( y ) == "function" and (...) ~= y then
        return y( ... )
      else
        return is_( ..., y, "x", true )
      end
    end
  end

  local function check( ... )
    for i = 1, n do
      local ok, msg = preds[ i ]( ... )
      if not ok then return false, msg end
    end
    return true, context()
  end
  F[ check ] = "all(...)?"
  return check
end


local function test_all()
  assert( M.all()( 1 ) )
  assert( M.all( M.is_number )( 1 ) )
  assert_not( M.all( M.is_string )( 1 ) )
  assert( M.all( M.is_number, M.is_number )( 1 ) )
  assert_not( M.all( M.is_number, M.is_string )( 1 ) )
  assert_not( M.all( M.is_string, M.is_table )( 1 ) )
  assert( M.all( M.resp( 1, 1 ) )( 1, 1 ) )
end


function M.none( ... )
  local n, preds = select( '#', ... ), { ... }
  for i = 1, n do
    local y = preds[ i ]
    preds[ i ] = function( ... )
      if type( y ) == "function" and (...) ~= y then
        return y( ... )
      else
        return is_( ..., y, "x", true )
      end
    end
  end

  local function check( ... )
    for i = 1, n do
      local ok, msg = preds[ i ]( ... )
      if ok then return false, msg end
    end
    return true, context()
  end
  F[ check ] = "none(...)?"
  return check
end


local function test_none()
  assert( M.none()( 1 ) )
  assert_not( M.none( M.is_number )( 1 ) )
  assert( M.none( M.is_string )( 1 ) )
  assert_not( M.none( M.is_number, M.is_number )( 1 ) )
  assert_not( M.none( M.is_number, M.is_string )( 1 ) )
  assert( M.none( M.is_string, M.is_table )( 1 ) )
  assert( M.none( M.resp( 1, 1, 1 ) )( 1, 1 ) )
  assert_not( M.none( M.resp( 1, 1 ) )( 1, 1 ) )
end


do
  local function len_context( v, n, m )
    return v, context()
  end
  F[ len_context ] = "select('#', ...) == ${3}?  (n: ${2})"

  function M.resp( ... )
    local m, preds = select( '#', ... ), { ... }
    for i = 1, m do
      local y = select( i, ... )
      preds[ i ] = function( x )
        return is_( x, y, "_"..i, true )
      end
    end

    local function check( ... )
      local n = select( '#', ... )
      if m ~= n then
        return notail( len_context( false, n, m ) )
      end
      for i = 1, m do
        local ok, msg = preds[ i ]( select( i, ... ) )
        if not ok then return false, msg end
      end
      return true, context()
    end
    F[ check ] = "resp(...)?  (i: ${i})"
    return check
  end
end


local function test_resp()
  assert( M.resp( 1, "a", {a=1} )( 1, "a", {a=1} ) )
  assert_not( M.resp( 1, "a", {a=2} )( 1, "a", {a=1} ) )
  assert_not( M.resp( 1, "a", {a=1} )( 1, "a", {a=1}, 1 ) )
  assert_not( M.resp( 1, "a", {a=1}, 1 )( 1, "a", {a=1} ) )
  assert( M.resp( 1, M.is_like"^a", {a=1} )( 1, "a", {a=1} ) )
end


do
  local function raises_context( p, ok, ... )
    if ok then return false, context() end
    local emsg = ...
    local v, msg = is_( emsg, p, "e", true  )
    return v, msg or context()
  end
  F[ raises_context ] = "raises(...)?  (e: ${@emsg})"

  function M.raises( p, f, ... )
    return raises_context( p, pcall( f, ... ) )
  end
end


local function test_raises()
  local function f() return 1 end
  local function g( msg ) error( msg, 0 ) end
  assert( M.raises( "xxx", g, "xxx" ) )
  assert_not( M.raises( "xxx", g, "abc" ) )
  assert_not( M.raises( 1, f ) )
  assert( M.raises( M.is_like( "^x" ), g, "xxx" ) )
  assert_not( M.raises( M.is_like( "^x" ), g, "abc" ) )
end


do
  local function error_context( emsg )
    return false, context()
  end
  F[ error_context ] = "error(${@1})!"

  local function returns_context( p, ok, ... )
    if not ok then
      return notail( error_context( (...) ) )
    end
    local v, msg
    if type( p ) == "function" and (...) ~= p then
      v, msg = p( ... )
    else
      -- wrap with is_ for shorter declarations and nicer stack traces
      v, msg = is_( ..., p, "x", true )
    end
    return v, msg or context()
  end
  F[ returns_context ] = "returns(...)?  (${2})"

  function M.returns( p, f, ... )
    return returns_context( p, pcall( f, ... ) )
  end
end


local function test_returns()
  local function f( ... ) return 1, "a", {a=1}, ... end
  local function g( msg ) error( msg, 0 ) end
  assert( M.returns( M.resp( 1, "a", {a=1}, 1 ), f, 1 ) )
  assert_not( M.returns( M.resp( 1, "a", {a=2} ), f ) )
  assert( M.returns( 1, f ) )
  assert_not( M.returns( "xxx", g, "xxx" ) )
end


do
  local function error_context( emsg )
    return false, context()
  end
  F[ error_context ] = "error(${@1})!"

  local function yields_context( chk, th, i, ok, ... )
    local status = co_status( th )
    if not ok then
      return notail( error_context( ... ) )
    elseif type( chk ) == "function" and (...) ~= chk then
      return notail( chk( ... ) )
    else
      return notail( is_( ..., chk, "x", true ) )
    end
  end
  F[ yields_context ] = "yields(...) (i: ${i}, status: ${status})"

  function M.yields( f, ... )
    if type( f ) ~= "function" then
      type_error( "yields", 1, "function", f, 2 )
    end
    -- on Lua 5.1 coroutine.create can only handle Lua functions, so
    -- we make sure that it gets one:
    local th = co_create( function( ... ) return f( ... ) end )
    local v, msg
    for i = 1,select( '#', ... ),2 do
      local args, chk = select( i, ... )
      if type( args ) ~= "table" then
        type_error( "yields", i+1, "table", args, 2 )
      end
      local m = args.n or #args
      v, msg = yields_context( chk, th, (i+1)/2,
                               co_resume( th, t_unpack( args, 1, m ) ) )
      if not v then
        return false, msg
      end
    end
    return v, msg
  end
end


local function test_yields()
  local function f( a, b )
    local c, d = coroutine.yield( a+1, b+1 )
    return c+1, d+1
  end
  assert( M.yields( f, { 1, 2 }, M.resp( 2, 3 ),
                       { 8, 9 }, M.resp( 9, 10 ) ) )
  assert( M.yields( f, { 1, 2 }, 2 ) )
  assert( M.yields( f, { 1, 2 }, M.is_gt( 1 ) ) )
  assert_not( M.yields( f, { 1, 2 }, M.resp( 2, 3 ),
                           { 8, 9 }, M.resp( 9, 10 ),
                           { 4, 5 }, M.resp( 5, 6 ) ) )
  assert( M.yields( type, { 1 }, "number" ) )
end


do
  local function done_context( i, n )
    return true, context()
  end
  F[ done_context ] = "iterates(...)  (${1}/${2})"

  local function error_context( emsg )
    return false, context()
  end
  F[ error_context ] = "error(${@1})!"

  local function iterates_context( i, n, chks, f, s, ok, var_1, ... )
    if not ok then
      return notail( error_context( var_1 ) )
    elseif var_1 == nil then
      return false, context()
    else
      local chk, v, msg = chks[ i ]
      if type( chk ) == "function" and chk ~= var_1 then
        v, msg = chk( var_1, ... )
      else
        v, msg = is_( var_1, chk, "var_1", true )
      end
      if not v then
        return false, msg or context()
      end
      if i+1 > n then
        return true, context()
      else
        return iterates_context( i+1, n, chks, f, s, pcall( f, s, var_1 ) )
      end
    end
  end
  F[ iterates_context ] = "iterates(...)  (${1}/${2})"

  function M.iterates( chks, f, s, var )
    if type( chks ) ~= "table" then
      type_error( "iterates", 1, "table", chks, 2 )
    end
    local n = chks.n or #chks
    if n < 1 then return done_context( 0, 0 ) end
    return iterates_context( 1, n, chks, f, s, pcall( f, s, var ) )
  end
end


local function test_iterates()
  assert( M.iterates( {M.resp( 1,"a" ), M.resp( 2,"b" ),
                       M.resp( 3,"c" ), M.resp( 4,"d" )},
                      ipairs( {"a","b","c","d"} ) ) )
  assert( M.iterates( {M.resp( 1,"a" ), M.resp( 2,"b" ),
                       M.resp( 3,"c" )},
                      ipairs( {"a","b","c","d"} ) ) )
  assert_not( M.iterates( {M.resp( 1,"a" ), M.resp( 2,"b" ),
                           M.resp( 3,"c" ), M.resp( 4,"d" )},
                          ipairs( {"a","b","c"} ) ) )
  assert_not( M.iterates( {M.resp( 1,"a" ), M.resp( 2,"b" ),
                           M.resp( 3,"f" ), M.resp( 4,"d" )},
                          ipairs( {"a","b","c","d"} ) ) )
  assert_not( M.iterates( {M.resp( 1,"a" ), M.resp( 2,"b" ),
                           M.resp( 3,M.is_number ), M.resp( 4,"d" )},
                          ipairs( {"a","b","c","d"} ) ) )
  local i = 0
  local function iter()
    if i < 3 then
      i = i + 1
      return i
    end
  end
  assert( M.iterates( {1, 2, 3}, iter ) )
  local function e_iter()
    error( "argh", 0 )
  end
  assert_not( M.iterates( {1, 2, 3}, e_iter ) )
end


-- return module table
return M

