local utils = require('cmake-simple.lib.utils')

local testcases = {}

function testcases:new(o)
  o = o or {test_list = {}}

  setmetatable(o, self)
  self.__index = self
  return o
end

function testcases:load_testlist(json)
  self.test_list = {}
  for _, test in ipairs(json.tests) do
    local cwd = utils.get_path(test.command[1])
    for _, prop in ipairs(test.properties) do
      if prop.name == 'WORKING_DIRECTORY' then
        cwd = prop.value
        break
      end
    end
    self.test_list[test.name] = {command = test.command, cwd = cwd, status = 'unk', output = nil}
  end
  return next(self.test_list) ~= nil
end

function testcases:has_tests() return next(self.test_list) ~= nil end

function testcases:update_test(name, details)
  if self.test_list[name] ~= nil then
    self.test_list[name] = vim.tbl_extend('keep', self.test_list[name], details)
    return true
  else
    return false
  end
end

function testcases:update_results(xml)
  self.summary = xml[1]["attrs"]
  local missing = {}
  for _, testcase in pairs(xml[1]["children"]) do
    P(testcase)
    local name = testcase["attrs"]["name"]
    ---@diagnostic disable-next-line: unused-local
    local classname = testcase["attrs"]["classname"]
    local status = testcase["attrs"]["status"]
    local output = ""
    for _, child in pairs(testcase["children"]) do
      if child["name"] == "system-out" then
        output = child["content"]
        break
      end
    end
    if self.test_list[name] ~= nil then
      print(name, status)
      self.test_list[name] = vim.tbl_extend('force', self.test_list[name], {status = status, output = output})
    else
      table.insert(missing, name)
    end
    P(self.test_list[name])
  end
  return missing
end

function testcases:get_by_index(index)
  for k, v in utils.idict(self.test_list) do if k == index then return v, self.test_list[v] end end
  return nil
end

function testcases:set_test_status(name, state)
  if self.test_list[name] ~= nil then
    self.test_list[name] = vim.tbl_extend('force', self.test_list[name], {status = state})
  end
end

function testcases:set_tests_status(state) for _, t in pairs(self.test_list) do t["status"] = state end end

return testcases
