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
    * wasting resource when not testing (embedded test functions get
      discarded by default unless you load them via the `testy.lua`
      script)
    * messing up your public interface (the tests are local and have
      access to internal functions that you might want to test)
*   The test code looks like regular Lua code (you use `assert` for
    your tests).


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
collect test functions from `require`d Lua modules recursively.

And that's about it, but for more information you can view an
annotated HTML version of the `testy.lua` source code rendered with
[Docco][1] on the [GitHub pages][2].

  [1]: http://jashkenas.github.io/docco/
  [2]: http://siffiejoe.github.io/lua-testy/


##                              Contact                             ##

Philipp Janda, siffiejoe(a)gmx.net

Comments and feedback are always welcome.


##                              License                             ##

`testy` is *copyrighted free software* distributed under the MIT
license (the same license as Lua 5.1). The full license text follows:

    testy (c) 2015 Philipp Janda

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

