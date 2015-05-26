package = "testy"
version = "0.1-1"
source = {
  url = "https://github.com/siffiejoe/lua-testy/archive/v0.1.zip",
  dir = "lua-testy-0.1"
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
build = {
  type = "none",
  install = {
    bin = {
      ["testy.lua"] = "src/testy.lua"
    }
  }
}

