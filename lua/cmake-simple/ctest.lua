local utils = require('cmake-simple.lib.utils')
local ntf = require('cmake-simple.lib.notification')
local ts_helper = require('cmake-simple.lib.ts_helper')
local scandir = require("plenary.scandir")
local window = require("cmake-simple.lib.window")
local command = require("cmake-simple.lib.command")
local xml_parser = require('cmake-simple.lib.xml_parser')
local testcases = require('cmake-simple.testcases')

local icons = {ok = "✓", running = "⌛", failed = "✗", skipped = "⚐", unknown = "⯑"}
local ctest = {}

function ctest:new(o)
  local log_filename = os.tmpname()
  o = o or {
    preset_list = {},
    selected_preset = nil,
    test_dir = nil,
    test_cases = testcases:new(),
    test_folders = {},
    testcases_buf = nil,
    summary = nil,
    job = 2,
    log_filename = log_filename,
    running = false
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

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

function ctest:testcases()
  self:search_test_folders()
  if self.test_dir == nil or next(self.test_folders) == nil then
    -- something went wrong
    return
  end

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
    if self.test_cases:load_testlist(json) then self:search_test_files() end
  end
  if result.code ~= 0 or not self.test_cases:has_tests() then
    ntf.notify("Failed to retrieve test list", vim.log.levels.ERROR)
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
        for k, v in pairs(files) do self.test_cases:update_test(k, v) end
        if count <= 0 then vim.schedule(function() self:update_testcases() end) end
      end
    })
  end
end

function ctest:search_test_folders()
  self.test_folders = {}
  self.test_dir = nil

  ---@diagnostic disable-next-line: undefined-field
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
        if vim.startswith(source_dir, s) then
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
  return self.test_cases:get_by_index(row)
end

function ctest:goto_test()
  local name, detail = self:_get_selected()
  if name == nil or detail == nil then return end
  if detail["filename"] ~= nil then
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
  if self.running then
    ntf.notify("CTest already running", vim.log.levels.WARN)
    return
  end
  self.running = true

  self.test_cases:set_tests_status("unk")
  self:update_testcases()

  local result_filename = os.tmpname()

  local cmd = command:new({name = "CTest", command = "ctest", log_filename = self.log_filename})
  local args = {"--output-on-failure", "--output-junit", result_filename}

  if self.selected_preset ~= nil then vim.list_extend(args, {'--preset', self.selected_preset}) end

  cmd:execute(args, "Running all tests", function(_)
    self.running = false;
    self:update_results(result_filename)
  end)

end

function ctest:run_test(name, _)
  if name == nil then return end

  if self.running then
    ntf.notify("CTest already running", vim.log.levels.WARN)
    return
  end
  self.running = true

  self.test_cases:set_test_status(name, "unk")
  self:update_testcases()

  local result_filename = os.tmpname()

  local cmd = command:new({name = "CTest", command = "ctest", log_filename = self.log_filename})
  local args = {"--output-on-failure", "--output-junit", result_filename, "-R", "^" .. name .. "$"}

  if self.selected_preset ~= nil then vim.list_extend(args, {'--preset', self.selected_preset}) end

  cmd:execute(args, "Running test " .. name, function(_)
    self.running = false;
    self:update_results(result_filename)
  end)
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
  vim.api.nvim_buf_set_lines(self.testcases_buf, 0, -1, true, {"Testcases", ""})
  vim.api.nvim_buf_add_highlight(self.testcases_buf, -1, "Title", 0, 0, 100)
  for k, v in pairs(self.test_cases.test_list) do
    local icon = icons.unknown
    if v["status"] == "run" then
      icon = icons.ok
    elseif v["status"] == "running" then
      icon = icons.running
    elseif v["status"] == "fail" then
      icon = icons.failed
    elseif v["status"] == "skipped" then
      icon = icons.skipped
    end
    utils.buf_append_colorized(self.testcases_buf, icon .. " " .. k, v["status"])
  end
  if self.summary ~= nil then
    local success = tonumber(self.summary["tests"]) - tonumber(self.summary["disabled"]) -
                        tonumber(self.summary["failures"]) - tonumber(self.summary["skipped"])

    vim.api.nvim_buf_set_lines(self.testcases_buf, -1, -1, true, {
      "", "   " .. icons.ok .. " " .. tostring(success) .. " " .. icons.failed .. " " .. self.summary["failures"],
      "   " .. icons.skipped .. " " .. self.summary["skipped"] .. " " .. icons.unknown .. " " ..
          self.summary["disabled"]
    })
  end

end

function ctest:update_results(result_filename)
  local file = io.open(result_filename, "rb")
  if file ~= nil then
    local str = file:read("*all")
    file:close()
    local xml = xml_parser(str)
    if xml ~= nil then
      local missing = self.test_cases:update_results(xml)
      for _, name in ipairs(missing) do ntf.notify("Test " .. name .. " not found", vim.log.levels.WARN) end
    else
      ntf.notify("Unable to parse junit result " .. result_filename, vim.log.levels.ERROR)
    end
  else
    ntf.notify("Unable to find junit result " .. result_filename, vim.log.levels.ERROR)
  end
  self:update_testcases()
end

return ctest
