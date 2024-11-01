local ctest = {}

function ctest:new(o)
  o = o or {}
  setmetatable(o, self)
  self.__index = self
  return o
end

--[[
ctest --show-only=json-v1 --preset test-debug
ctest --quiet --output-on-failure --output-junit /tmp/nvim.marco/uxQ42Y/0 --output-log /tmp/nvim.marco/uxQ42Y/1 --preset test-debug

]] --

function ctest:testcases() end

return ctest
