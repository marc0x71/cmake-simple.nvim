local utils = require('cmake-simple.lib.utils')

local ctest = {}

function ctest:new(o)
  o = o or {preset_list = {}, preset = nil, test_list = {}}
  setmetatable(o, self)
  self.__index = self
  return o
end

--[[
ctest --show-only=json-v1 --preset test-debug
ctest --quiet --output-on-failure --output-junit /tmp/nvim.marco/uxQ42Y/0 --output-log /tmp/nvim.marco/uxQ42Y/1 --preset test-debug

]] --

function ctest:load_presets()
  self.presets = {}
  local cmd = {"ctest", "--list-presets"}
  local result = vim.system(cmd, {text = true}):wait()

  if (result.code ~= 0) then
    -- If there is an error no presets has been defined
    return
  end

  for s in result.stdout:gmatch("[^\r\n]+") do
    local name = string.match(s, '.*"(.*)".*')
    if name ~= nil or name ~= '' then table.insert(self.preset_list, name) end
  end
end

function ctest:show_testcases()
  self.test_list = {}
  local cmd = {"ctest", "--show-only=json-v1"}
  if next(self.preset_list) ~= nil then
    if self.preset == nil then
      vim.ui.select(self.preset_list, {prompt = "Select preset"}, function(select) self.selected_preset = select end)
    end
    vim.list_extend(cmd, {'--preset', self.selected_preset})
  end
  local result = vim.system(cmd, {text = true}):wait()
  if result.code == 0 then
    local json = vim.json.decode(result.stdout)
    for _, test in ipairs(json.tests) do
      local cwd = utils.get_path(test.command[1])
      for _, prop in ipairs(test.properties) do
        if prop.name == 'WORKING_DIRECTORY' then
          cwd = prop.value
          break
        end
      end
      self.test_list[test.name]={
        source = '',
        line = 0,
        command = test.command,
        cwd = cwd,
        status = 'unk',
        output = nil
      }
    end
  end
end


return ctest
