[![Build Status](https://travis-ci.org/siffiejoe/lua-testy.svg?branch=master)](https://travis-ci.org/siffiejoe/lua-testy)

#             Testy -- Easy Unit Testing for Lua Modules             #

##                           Introduction                           ##

Good software engineering practices include testing your module code
on a regular basis to make sure that changes to your code did not
break anything. There are many full-featured unit testing frameworks
available for Lua, but this one aims to be as unobtrusive as possible.

Features:

*   Pure Lua (compatible with Lua 5.1 and up), no other external
    dependencies.
*   You can embed the test functions *inside* your module code without
    * wasting resources when not testing (embedded test functions get
      discarded by default unless you load them via the `testy.lua`
      script)
    * messing up your public interface (the tests are local and have
      access to internal functions that you might want to test)
*   The test code looks like regular Lua code (you use `assert` for
    your tests).
*   Now includes (and autoloads) the `testy.extra` module, which
    contains functions for specifying expected return values, expected
    yields, expected iteration values, expected errors, etc. in a
    declarative way.


##                          Getting Started                         ##

You write your tests using `assert` in local functions embedded in
your Lua module (or in separate Lua files if you prefer). The test
functions are identified by having a `test_` prefix in their names.
E.g.:

```lua
-- module1.lua
local M = {}

function M.func1()
  return 1
end

-- this is a test function for the module function `M.func1()`
local function test_func1()
  assert( M.func1() == 1, "func1() should always return 1" )
  assert( M.func1() ~= 2, "func1() should never return 2" )
  assert( type( M.func1() ) == "number" )
end

function M.func2()
  return 2
end

-- this is a test function for the module function `M.func2()`
local function test_func2()
  assert( M.func2() == 2 )
  assert( M.func2() ~= M.func1() )
end

return M
```

You run your tests using the `testy.lua` script:

```
$ testy.lua module1.lua
func1 ('module1.lua')   ...
func2 ('module1.lua')   ..
5 tests (5 ok, 0 failed, 0 errors)
```

The `assert`s won't kill your test run even if they are false. Instead
they will update the test statistics, print a progress indicator, and
continue on. This behavior of `assert` only happens when directly
called by a test function. Anywhere else the `assert` function behaves
normally (thus terminating the program with an error if the condition
evaluates to false). Instead of the `assert` function you can also use
the new global function `testy_assert`. This function works the same
way, but its behavior doesn't depend on the function that calls it.
This is useful if you want to run a test in a function callback, or if
you want to write your own helper assertion functions.

You can pass multiple Lua files to the `testy.lua` script, or you can
pass the `-r` command line flag, which causes `testy.lua` to also
collect test functions from `require`d Lua modules recursively. You
may also switch to [TAP][3]-formatted output for third-party test
report tools like e.g. `prove` using the `-t` command line flag.

```
$ prove --exec "testy.lua -t" module1.lua
module1.lua .. ok
All tests successful.
Files=1, Tests=5,  0 wallclock secs ( 0.02 usr +  0.01 sys =  0.03 CPU)
Result: PASS
```

If you installed **Testy** via LuaRocks, you should also have a Lua
version-specific script `testy-5.x` available, in case you want to
run the test suite with different Lua versions.

And that's about it, but for more information you can view an
annotated HTML version of the `testy.lua` source code rendered with
[Docco][1] on the [GitHub pages][2].

  [1]: http://jashkenas.github.io/docco/
  [2]: http://siffiejoe.github.io/lua-testy/
  [3]: http://testanything.org/tap-specification.html


##                     The `testy.extra` Module                     ##

The `testy.lua` script tries to `require()` the `testy.extra` module
and makes all exported functions available as global variables during
test execution. Failure to load `testy.extra` is silently ignored.

The following functions are part of `testy.extra`:

*   `is( x, y ) ==> boolean, string`

    `is( y )( x ) ==> boolean, string`

    The `is` function is roughly equivalent to the equality operator,
    but for certain values `y` is interpreted as a *template* or
    *prototype*: If `y` is a function (and not primitively equal to
    `x`), it is called as a unary predicate with `x` as argument. If
    `y` is a table (and not primitively equal to `x`), it is iterated,
    and the fields of `y` are compared to the corresponding fields of
    `x` using the same rules as for `is`. The `is` function also
    correctly handles `NaN` values.

    The second form of `is` can be used to create unary predicates.
    (I.e. `is( y )` returns a unary function that when applied to an
    `x` is equivalent to the results of an `is( x, y )` call.)

*   `is_<type>( x ) ==> boolean, string`

    Unary predicates that check the type of the argument `x`.
    There's one function for each of the eight primitive Lua types,
    and additionally an `is_cdata` function for LuaJIT's FFI type.

*   `is_len( x, y ) ==> boolean, string`

    `is_len( y )( x ) ==> boolean, string`

    The `is_len` function checks whether `#x` is equal to `y`. The
    second form of `is_len` can be used to create unary predicates.
    (See `is` above!)

*   `is_like( x, y ) ==> boolean, string`

    `is_like( y )( x ) ==> boolean, string`

    The `is_like` function uses `string.match` to check whether the
    string `x` matches the pattern `y`. The second form of `is_like`
    can be used to create unary predicates. (See `is` above!)

*   `is_eq( x, y ) ==> boolean, string`

    `is_eq( y )( x ) ==> boolean, string`

    The `is_eq` function checks for (deep) equality between `x` and
    `y`. It correctly handles `NaN` values, `__eq` metamethods, and
    cyclic tables. This is a stricter version of the `is` function
    above without the prototype/template stuff.

    The second form of `is_eq` can be used to create unary predicates.
    (See `is` above!)

*   `is_raweq( x, y ) ==> boolean, string`

    `is_raweq( y )( x ) ==> boolean, string`

    The `is_raweq` function checks for raw equality between `x` and
    `y` (almost like the `rawequal` function from Lua's standard
    library): it doesn't check `__eq` metamethods or recurse into
    subtables. It does however correctly handle `NaN` values.

    The second form of `is_raweq` can be used to create unary
    predicates. (See `is` above!)

*   `is_gt( x, y ) ==> boolean, string`

    `is_gt( y )( x ) ==> boolean, string`

    The `is_gt` function checks whether `x > y`. The second form can
    be used to create unary predicates. (See `is` above!)

*   `is_lt( x, y ) ==> boolean, string`

    `is_lt( y )( x ) ==> boolean, string`

    The `is_lt` function checks whether `x < y`. The second form can
    be used to create unary predicates. (See `is` above!)

*   `is_ge( x, y ) ==> boolean, string`

    `is_ge( y )( x ) ==> boolean, string`

    The `is_ge` function checks whether `x >= y`. The second form can
    be used to create unary predicates. (See `is` above!)

*   `is_le( x, y ) ==> boolean, string`

    `is_le( y )( x ) ==> boolean, string`

    The `is_le` function checks whether `x <= y`. The second form can
    be used to create unary predicates. (See `is` above!)

*   `any( ... )( ... ) ==> boolean, string`

    `any( ... )` creates a n-ary predicate that succeeds if at least
    one of its arguments matches the second vararg list. The arguments
    to `any` are interpreted as by the `is` function above, except
    that functions will be treated as n-ary not unary. The `any`
    function evaluates from left to right and short-circuits similar
    to the `or` operator.

*   `all( ... )( ... ) ==> boolean, string`

    `all( ... )` creates a n-ary predicate that succeeds if all of its
    arguments match the second vararg list. The arguments to `all` are
    interpreted as by the `is` function above, except that functions
    will be treated as n-ary not unary. The `all` function evaluates
    from left to right and short-circuits similar to the `and`
    operator.

*   `none( ... )( ... ) ==> boolean, string`

    `none( ... )` creates a n-ary predicate that succeeds only if all
    of its arguments fail to match the second vararg list. The
    arguments to `none` are interpreted as by the `is` function above,
    except that functions will be treated as n-ary not unary. The
    `none` function evaluates from left to right and short-circuits
    similar to the `and` operator (with the individual operands
    negated).

*   `resp( ... )( ... ) ==> boolean, string`

    `resp( ... )` creates an n-ary predicate that tries to match each
    argument to the corresponding value in the first vararg list,
    *resp*ectively. The values in the first argument list are
    interpreted as by the `is` function above.

*   `raises( p, f, ... ) ==> boolean, string`

    `raises` `pcall`s the function `f` with the given arguments and
    matches the error object to `p`. `p` is interpreted as by the `is`
    function above. If `f` does not raise an error, the `raises`
    function returns `false`.

*   `returns( p, f, ... ) ==> boolean, string`

    `returns` `pcall`s the function `f` with the given arguments and
    applies the predicate `p` to the return values. `p` is interpreted
    as by the `is` function above, except that functions are treated
    as n-ary not unary. If `f` raises an error, the `returns` function
    returns `false` (plus message).

*   `yields( a1, p1, ..., f ) ==> boolean, string`

    `yields` creates a new coroutine from `f` and resumes it multiple
    times using the arguments in the tables `a1`, `a2`, ..., and
    compares the resulting values using the predicates `p1`, `p2`,
    ..., respectively. The arguments must be contained in tables as
    returned by `table.pack` (the `n` field is optional if the table
    is a proper sequence). The predicates `px` usually are n-ary
    predicates, but they can be anything that `is` can handle (in
    which case they are *unary* tests, though). `yields` only succeeds
    if `f` yields often enough, no errors are raised, and all
    predicates match the corresponding yielded/returned values.

*   `iterates( ps, f, s, var ) ==> boolean, string`

    `iterates` compares the values created by the iterator triple `f`,
    `s`, `var`, to the values contained in the table `ps`. `ps` is a
    table as returned by `table.pack` (the `n` field is optional if
    the table is a proper sequence) and usually contains n-ary
    predicates, but it may contain anything that `is` can handle (in
    which case they are *unary* tests, though). `iterates` succeeds
    only if the iterator iterates often enough, no errors are raised
    by `f`, and the tuples created during iteration match the
    predicates in `ps`.


##                              Contact                             ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                              License                             ##

**Testy** is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    Testy (c) 2015,2016 Philipp Janda

    Permission is hereby granted, free of charge, to any person obtaining
    a copy of this software and associated documentation files (the
    "Software"), to deal in the Software without restriction, including
    without limitation the rights to use, copy, modify, merge, publish,
    distribute, sublicense, and/or sell copies of the Software, and to
    permit persons to whom the Software is furnished to do so, subject to
    the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHOR OR COPYRIGHT HOLDER BE LIABLE FOR ANY
    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

