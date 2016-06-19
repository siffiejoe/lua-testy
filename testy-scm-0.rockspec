package = "testy"
version = "scm-0"
source = {
  url = "git://github.com/siffiejoe/lua-testy.git",
}
description = {
  summary = "Easy unit testing for Lua modules.",
  detailed = [[
    A small Lua scripts that extracts local test functions from
    Lua modules (or separate test scripts), runs those tests, and
    prints nice statistics about failed/passed tests.
  ]],
  homepage = "https://github.com/siffiejoe/lua-testy/",
  license = "MIT"
}
dependencies = {
  "lua >= 5.1, < 5.4"
}

-- detect Lua version; based on a trick posted on lua-l:
-- http://lua-users.org/lists/lua-l/2016-05/msg00297.html
local f = function() return function() end end
local t = { nil, [false] = "5.1", [true] = "5.2",
            [1/'-0'] = "5.3", [1] = "5.1" }
local V = t[1] or t[1/0] or t[f()==f()]

build = {
  type = "builtin",
  modules = {
    ["testy.extra"] = "src/testy/extra.lua"
  },
  install = {
    bin = {
      ["testy.lua"] = "src/testy.lua",
      ["testy-"..V] = "src/testy.lua",
    }
  }
}

