local utils = require('cmake-simple.lib.utils')
local ntf = require('cmake-simple.lib.notification')
local ts_helper = require('cmake-simple.lib.ts_helper')
local scandir = require("plenary.scandir")
local window = require("cmake-simple.lib.window")
local command = require("cmake-simple.lib.command")
local xml_parser = require('cmake-simple.lib.xml_parser')
local testcases = require('cmake-simple.testcases')
local dap = require("dap")

local icons = {ok = "✓", running = "⌛", failed = "✗", skipped = "⚐", unknown = "⯑"}
local ctest = {}

function ctest:new(opts)
  local log_filename = os.tmpname()
  local o = {
    preset_list = {},
    selected_preset = nil,
    test_dir = nil,
    test_cases = testcases:new(),
    test_folders = {},
    testcases_buf = nil,
    testcases_win = nil,
    log_filename = log_filename,
    running = false,
    last_position = nil,
    opts = opts
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function ctest:load_presets()
  self.presets = {}
  self.selected_preset = nil
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

function ctest:get_preset(callback)
  if self.selected_preset == nil then
    utils.select_from_list("Select preset", self.preset_list, function(select)
      self.selected_preset = select
      callback(select)
    end)
  else
    callback(self.selected_preset)
  end
end

function ctest:_load_json_testcases(cmd)
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

function ctest:testcases()
  self:search_test_folders()
  if self.test_dir == nil or next(self.test_folders) == nil then
    -- something went wrong
    return
  end

  local cmd = {"ctest", "--show-only=json-v1", "--test-dir", self.test_dir}
  if next(self.preset_list) ~= nil then
    self:get_preset(function(select)
      vim.list_extend(cmd, {'--preset', select})
      self:_load_json_testcases(cmd)
    end)
  else
    self:_load_json_testcases(cmd)
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
  self.last_position = r
  local row = r - 4;
  if row < 0 then return nil end
  local content = vim.api.nvim_get_current_line()
  local name = content:gsub("[^%s]*%s", "")
  return name, self.test_cases.test_list[name]
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
  else
    ntf.notify("No source code found for " .. name)
  end
end

function ctest:run_all_test()
  if self.running then
    ntf.notify("CTest already running", vim.log.levels.WARN)
    return
  end
  self.running = true

  local _ = self:_get_selected()
  self.test_cases:set_tests_status("unk")
  self:update_testcases()

  local result_filename = os.tmpname()

  local cmd = command:new({name = "CTest", command = "ctest", log_filename = self.log_filename})
  local args = {"--output-on-failure", "--output-junit", result_filename}
  if self.opts:get().jobs > 1 then args = vim.list_extend(args, {'-j', tostring(self.opts:get().jobs)}) end

  if self.selected_preset ~= nil then vim.list_extend(args, {'--preset', self.selected_preset}) end

  cmd:execute(args, "Running all tests", function(_)
    self.running = false;
    self:update_results(result_filename)
    vim.api.nvim_win_set_cursor(self.testcases_win, {self.last_position, 0})
  end)

end

function ctest:test_log(name, detail)
  if name == nil then return end
  if detail.output == nil then
    ntf.notify("No log found for test " .. name, vim.log.levels.WARN)
    return
  end
  local buf, _ = window.centered_window()
  vim.api.nvim_set_option_value("readonly", false, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", true, {buf = buf})

  -- press 'q' or 'esc' to close window
  for _, key in ipairs({'q', '<esc>'}) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '<cmd>close<cr>', {nowait = true, noremap = true, silent = true})
  end

  local lines = vim.split(detail.output, "\n")
  vim.api.nvim_buf_set_lines(buf, -1, -1, true, lines)

  vim.api.nvim_set_option_value("readonly", true, {buf = buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = buf})
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
    vim.api.nvim_win_set_cursor(self.testcases_win, {self.last_position, 0})
  end)
end

function ctest:debug_test(name, details)
  if name == nil then return end

  ntf.notify("Debug test " .. name, vim.log.levels.INFO)

  local dap_config = {
    args = {unpack(details.command, 2)},
    cwd = details.cwd,
    program = details.command[1],
    request = "launch",
    name = "Debug test " .. name,
    type = self.opts:get().dap_adapter
  }

  vim.api.nvim_buf_delete(self.testcases_buf, {})
  self.testcases_buf = nil;

  dap.run(dap_config)
end

function ctest:_create_win_testcases()
  if self.testcases_buf == nil or not vim.api.nvim_buf_is_valid(self.testcases_buf) then
    self.main_window = vim.api.nvim_get_current_win();
    local buf, win = window.panel_window(self.test_cases.max_name_len + 3)
    vim.api.nvim_set_option_value("buftype", "nofile", {buf = buf})
    vim.api.nvim_buf_set_keymap(buf, 'n', 'q', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function()
        vim.api.nvim_buf_delete(self.testcases_buf, {})
        self.testcases_buf = nil;
      end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<esc>', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function()
        vim.api.nvim_buf_delete(self.testcases_buf, {})
        self.testcases_buf = nil;
      end
    })
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
    vim.api.nvim_buf_set_keymap(buf, 'n', 'd', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:debug_test(self:_get_selected()) end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'l', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:test_log(self:_get_selected()) end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', 'R', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:run_all_test() end
    })
    vim.api.nvim_buf_set_keymap(buf, 'n', '<F5>', '', {
      nowait = true,
      noremap = true,
      silent = true,
      callback = function() self:refresh() end
    })
    self.testcases_buf = buf
    self.testcases_win = win

    vim.api.nvim_set_option_value("bufhidden", "wipe", {buf = self.testcases_buf})
    vim.api.nvim_set_option_value("modifiable", false, {buf = self.testcases_buf})
    vim.api.nvim_set_option_value("readonly", true, {buf = self.testcases_buf})
  else
    vim.api.nvim_set_option_value("readonly", false, {buf = self.testcases_buf})
    vim.api.nvim_set_option_value("modifiable", true, {buf = self.testcases_buf})
    vim.api.nvim_buf_set_lines(self.testcases_buf, 0, -1, false, {})
    vim.api.nvim_set_option_value("readonly", true, {buf = self.testcases_buf})
    vim.api.nvim_set_option_value("modifiable", false, {buf = self.testcases_buf})
  end
  return self.testcases_buf
end

function ctest:update_testcases()
  self:_create_win_testcases()

  vim.api.nvim_set_option_value("readonly", false, {buf = self.testcases_buf})
  vim.api.nvim_set_option_value("modifiable", true, {buf = self.testcases_buf})

  vim.api.nvim_buf_set_lines(self.testcases_buf, 0, -1, true, {"Testcases", ""})
  vim.api.nvim_buf_add_highlight(self.testcases_buf, -1, "Title", 0, 0, 100)
  local summary = self.test_cases.summary
  if summary ~= nil then
    local success = icons.ok .. " " .. tostring(summary.success)
    local failed = icons.failed .. " " .. tostring(summary.failed)
    local skipped = icons.skipped .. " " .. tostring(summary.skipped)
    vim.api
        .nvim_buf_set_lines(self.testcases_buf, -1, -1, true, {" " .. success .. " " .. failed .. " " .. skipped, ""})
    vim.api.nvim_buf_add_highlight(self.testcases_buf, -1, "DiagnosticOk", 2, 0, success:len() + 1)
    vim.api.nvim_buf_add_highlight(self.testcases_buf, -1, "DiagnosticError", 2, success:len() + 2,
                                   success:len() + failed:len() + 2)
    vim.api.nvim_buf_add_highlight(self.testcases_buf, -1, "DiagnosticInfo", 2, success:len() + failed:len() + 3,
                                   success:len() + failed:len() + skipped:len() + 3)
  end

  local qf_items = {}

  for _, k in pairs(utils.orderedPairs(self.test_cases.test_list)) do
    local v = self.test_cases.test_list[k]
    local icon = icons.unknown
    if v["status"] == "run" then
      icon = icons.ok
    elseif v["status"] == "running" then
      icon = icons.running
    elseif v["status"] == "fail" then
      icon = icons.failed
      table.insert(qf_items, {filename = v["filename"], lnum = v["row"], type = "E", text = "Test fails"})
    elseif v["status"] == "skipped" then
      icon = icons.skipped
    end
    utils.buf_append_colorized(self.testcases_buf, icon .. " " .. k, v["status"])
  end
  vim.fn.setqflist({}, 'r', {title = "Test results", items = qf_items})

  vim.api.nvim_set_option_value("readonly", true, {buf = self.testcases_buf})
  vim.api.nvim_set_option_value("modifiable", false, {buf = self.testcases_buf})
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

function ctest:refresh() self:testcases() end

return ctest
