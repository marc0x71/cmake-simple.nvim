local utils = require('cmake-simple.lib.utils')
local ntf = require('cmake-simple.lib.notification')
local ts_helper = require('cmake-simple.lib.ts_helper')
local scandir = require("plenary.scandir")
local window = require("cmake-simple.lib.window")

local icons = {ok = "✓", running = "⌛", failed = "✗", skipped = "⚐", unknown = "⯑"}
local ctest = {}

function ctest:new(o)
  o = o or
          {
        preset_list = {},
        selected_preset = nil,
        test_dir = nil,
        test_list = {},
        test_folders = {},
        testcases_buf = nil
      }
  setmetatable(o, self)
  self.__index = self
  return o
end

--[[
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
    if self.selected_preset == nil then
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
        if count <= 0 then vim.schedule(function() self:update_testcases() end) end
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

function ctest:_get_selected()
  local r, _ = unpack(vim.api.nvim_win_get_cursor(0))
  local row = r - 2;
  if row < 0 then return nil end
  for k, v in utils.idict(self.test_list) do
    if k == row then return v, self.test_list[v] end
  end
  return nil
end

function ctest:goto_test()
  local name, detail = self:_get_selected()
  if name == nil or detail == nil then return end
  if detail["filename"] ~= nil then
    print(self.main_window)
    print(vim.api.nvim_win_is_valid(self.main_window))
    if not vim.api.nvim_win_is_valid(self.main_window) then
      ntf.notify("Main window has been close, please try again")
      pcall(vim.api.nvim_win_close, 0, true)
      self.testcases_buf = nil
      return
    end
    vim.api.nvim_set_current_win(self.main_window)
    vim.cmd('edit ' .. vim.fn.fnameescape(detail["filename"]) .. '|' .. detail['row'])
  end
end

function ctest:run_all_test()
  -- TODO
  ntf.notify("Running all test")
end

function ctest:run_test(name, detail)
  if name == nil then return end
  P(detail)
  ntf.notify("Running test " .. name, vim.log.levels.INFO)
  -- TODO
end

function ctest:_create_win_testcases()
  if self.testcases_buf == nil or not vim.api.nvim_buf_is_valid(self.testcases_buf) then
    self.main_window = vim.api.nvim_get_current_win();
    local buf, _ = window.panel_window()
    vim.api.nvim_buf_set_keymap(buf, 'n', '<enter>', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:goto_test() end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'r', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:run_test(self:_get_selected()) end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'R', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:run_all_test() end
    })
    self.testcases_buf = buf
  else
    vim.api.nvim_buf_set_lines(self.testcases_buf, 0, -1, false, {})
  end
  return self.testcases_buf
end

function ctest:update_testcases()
  self:_create_win_testcases()
  utils.buf_append_colorized(self.testcases_buf, "Testcases", "start")
  vim.api.nvim_buf_set_lines(self.testcases_buf, 0, -1, true, {"Testcases", ""})
  for k, v in pairs(self.test_list) do
    local icon = icons.unknown
    if v["status"] == "run" then
      icon = icons.ok
    elseif v["status"] == "running" then
      icon = icons.running
    elseif v["status"] == "failed" then
      icon = icons.failed
    elseif v["status"] == "skipped" then
      icon = icons.skipped
    end
    utils.buf_append_colorized(self.testcases_buf, icon .. " " .. k, "")
  end
end

return ctest
