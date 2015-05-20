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
build = {
  type = "none",
  install = {
    bin = {
      ["testy.lua"] = "src/testy.lua"
    }
  }
}

