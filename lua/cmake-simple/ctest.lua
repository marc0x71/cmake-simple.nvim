local utils = require('cmake-simple.lib.utils')
local ntf = require('cmake-simple.lib.notification')
local ts_helper = require('cmake-simple.lib.ts_helper')
local scandir = require("plenary.scandir")

local ctest = {}

function ctest:new(o)
  o = o or {preset_list = {}, preset = nil, test_dir = nil, test_list = {}, test_folders = {}}
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

local function _decode_testlist(json)
  local result = {}
  for _, test in ipairs(json.tests) do
    local cwd = utils.get_path(test.command[1])
    for _, prop in ipairs(test.properties) do
      if prop.name == 'WORKING_DIRECTORY' then
        cwd = prop.value
        break
      end
    end
    result[test.name] = {command = test.command, cwd = cwd, status = 'unk', output = nil}
  end
  return result
end

function ctest:testcases()
  self:search_test_folders()
  if self.test_dir == nil or next(self.test_folders) == nil then
    -- something went wrong
    return
  end

  self.test_list = {}
  local cmd = {"ctest", "--show-only=json-v1", "--test-dir", self.test_dir}
  if next(self.preset_list) ~= nil then
    if self.preset == nil then
      vim.ui.select(self.preset_list, {prompt = "Select preset"}, function(select) self.selected_preset = select end)
    end
    vim.list_extend(cmd, {'--preset', self.selected_preset})
  end

  local result = vim.system(cmd, {text = true}):wait()
  if result.code == 0 then
    local json = vim.json.decode(result.stdout)
    self.test_list = _decode_testlist(json)
    if next(self.test_list) ~= nil then self:search_test_files() end
  end
  if result.code ~= 0 or next(self.test_list) == nil then
    ntf.notify("Failed to locate retrieve test list", vim.log.levels.ERROR)
    return
  end

end

function ctest:_show_testcases()
  -- TODO show testcases window
end

function ctest:search_test_files()
  local files = {}
  local count = vim.tbl_count(self.test_folders)
  for _, folder in ipairs(self.test_folders) do
    scandir.scan_dir_async(folder, {
      respect_gitignore = true,
      silent = true,
      search_pattern = {".*.C$", ".*.cxx$", ".*.cc$", ".*.cpp$", ".*.c++$"},
      on_insert = function(filename)
        local local_tests = ts_helper.extract_test_details(filename)
        files = vim.tbl_extend('keep', files, local_tests)
      end,
      on_exit = function()
        count = count - 1
        for k, v in pairs(files) do
          if self.test_list[k] ~= nil then self.test_list[k] = vim.tbl_extend('keep', self.test_list[k], v) end
        end
        if count <= 0 then
          self:_show_testcases()
        end
      end
    })
  end
end

function ctest:search_test_folders()
  self.test_folders = {}
  self.test_dir = nil

  local cwd = vim.loop.cwd()
  local folders = scandir.scan_dir(cwd, {
    respect_gitignore = false,
    depth = 4,
    search_pattern = "CTestTestfile.cmake",
    silent = true
  })
  if next(folders) == nil then
    ntf.notify("Failed to locate CTestTestfile", vim.log.levels.WARN)
    return
  end
  self.test_dir = utils.get_path(folders[1])

  for _, filename in ipairs(folders) do
    local content = utils.read_all(filename) or ''
    local source_dir = string.match(content, [[.*Source directory: ([^%s]+).*]], 0)
    if source_dir ~= nil then
      local found = false
      for _, s in ipairs(self.test_folders) do
        if utils.starts_with(source_dir, s) then
          found = true
          break
        end
      end
      if not found then table.insert(self.test_folders, source_dir) end
    end
  end
  if next(self.test_folders) == nil then ntf.notify("Failed to locate tests folders", vim.log.levels.WARN) end
end

return ctest
