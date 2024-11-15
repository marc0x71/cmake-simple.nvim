local utils = require('cmake-simple.lib.utils')

local testcases = {}

function testcases:new(o)
  o = o or {test_list = {}, summary = nil, max_name_len = 1}

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
    self.test_list[test.name] = {name = test.name, command = test.command, cwd = cwd, status = 'unk', output = nil}
    if test.name:len() > self.max_name_len then self.max_name_len = test.name:len() end
  end
  self:_reset_summary()
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
  self:_update_summary(xml[1]["attrs"])
  local missing = {}
  for _, testcase in pairs(xml[1]["children"]) do
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
      self.test_list[name] = vim.tbl_extend('force', self.test_list[name], {status = status, output = output})
    else
      table.insert(missing, name)
    end
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

function testcases:_reset_summary()
  self.summary = {total = vim.tbl_count(self.test_list), success = 0, failed = 0, skipped = 0}
end

function testcases:_update_summary(attrs)
  if self.summary == nil then return end
  local disabled = tonumber(attrs["disabled"] or "0")
  local failures = tonumber(attrs["failures"] or "0")
  local tests = tonumber(attrs["tests"] or "0")
  local skipped = tonumber(attrs["skipped"] or "0")
  self.summary = {
    total = tests,
    success = (tests - skipped - disabled - failures),
    failed = failures,
    skipped = skipped
  }
end

return testcases
