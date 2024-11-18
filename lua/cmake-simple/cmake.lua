local command = require("cmake-simple.lib.command")
local notification = require('cmake-simple.lib.notification')
local window = require('cmake-simple.lib.window')
local utils = require('cmake-simple.lib.utils')
local fileapi = require("cmake-simple.fileapi")
local ntf = require('cmake-simple.lib.notification')
local dap = require("dap")
local cmake = {}

local build_states = {running = '', success = '󰗠', failed = '󰅙', unknown = ''}

function cmake:new(opts, log_filename)
  local o = {
    cwd = ".",
    preset_list = {configure = {}, build = {}, test = {}},
    selected_preset = {configure = nil, build = nil, test = nil},
    running = false,
    opts = opts,
    log_filename = log_filename,
    build_status = build_states.unknown,
    build_path = opts:get().build_folder,
    fileapi = nil
  }
  setmetatable(o, self)
  self.__index = self

  return o
end

---Load CMake preset list
function cmake:load_presets()
  for _, preset_type in pairs({"configure", "build", "test"}) do
    local cmd = {"cmake", "--list-presets=" .. preset_type}
    local result = vim.system(cmd, {text = true}):wait()

    if (result.code ~= 0) then
      -- If there is an error no presets has been defined
      return
    end

    for s in result.stdout:gmatch("[^\r\n]+") do
      local name = string.match(s, '.*"(.*)".*')
      if name ~= nil or name ~= '' then table.insert(self.preset_list[preset_type], name) end
    end
  end
end

function cmake:_on_command_exit(status, update_targets)
  update_targets = update_targets or false
  self.running = false
  if status == 0 then
    self.build_status = build_states.success
    self:_update_build_folder()
    if update_targets then self.fileapi:update() end
  else
    self.build_status = build_states.failed
  end
  if status ~= 0 and not self.opts:get().show_command_logs then self:show_log() end
end

function cmake:get_preset(name, callback)
  if self.selected_preset[name] == nil then
    utils.select_from_list("Select preset", self.preset_list[name], function(select)
      self.selected_preset[name] = select
      callback(select)
    end)
  else
    callback(self.selected_preset[name])
  end
end

function cmake:_update_build_folder()
  for line in io.lines(self.log_filename) do
    if line:find("Build files have been written to") then
      local path = line:match("[^:]*:%s(.*)")
      if self.build_path ~= path then
        self.build_path = path
        self.fileapi = fileapi:new({path = self.build_path})
        self.fileapi:init_model()
        self:configure(true)
      end
    end
  end
end

function cmake:configure_from_preset(silent_mode)
  silent_mode = silent_mode or false
  local cmd = command:new({
    log_filename = self.log_filename,
    show_command_logs = self.opts:get().show_command_logs,
    silent_mode = silent_mode
  })
  self:get_preset("configure", function(preset_name)
    local args = {"--preset", preset_name}
    self.running = true
    cmd:execute(args, "Configure using preset " .. preset_name,
                function(status) self:_on_command_exit(status, true); end)
  end)
end

function cmake:configure(silent_mode)
  silent_mode = silent_mode or false
  if self.running then
    notification.notify("CMake already running", "warn")
    return
  end
  if next(self.preset_list["configure"]) ~= nil then
    self:configure_from_preset()
    return
  end
  local cmd = command:new({
    log_filename = self.log_filename,
    show_command_logs = self.opts:get().show_command_logs,
    silent_mode = silent_mode
  })
  local args = {"-S", self.cwd, "-B", self.opts:get().build_folder}
  self.running = true
  cmd:execute(args, "Configure", function(status) self:_on_command_exit(status, true) end)
end

function cmake:build_from_preset()
  local cmd = command:new({log_filename = self.log_filename, show_command_logs = self.opts:get().show_command_logs})
  self:get_preset("build", function(preset_name)
    local args = {"--build", "--preset", preset_name}
    if self.opts:get().clean_first then args = vim.list_extend(args, {'--clean-first'}) end
    if self.opts:get().jobs > 1 then args = vim.list_extend(args, {'-j', tostring(self.opts:get().jobs)}) end
    self.running = true
    self.build_status = build_states.running
    cmd:execute(args, "Build using preset " .. preset_name, function(status) self:_on_command_exit(status) end)
  end)
end

function cmake:build()
  if self.running then
    notification.notify("CMake already running", "warn")
    return
  end
  if next(self.preset_list["build"]) ~= nil then
    self:build_from_preset()
    return
  else
    vim.fn.mkdir(self.opts:get().build_folder, "p")
  end

  local args = {"--build", self.opts:get().build_folder}
  if self.opts:get().clean_first then args = vim.list_extend(args, {'--clean-first'}) end
  if self.opts:get().jobs > 1 then args = vim.list_extend(args, {'-j', tostring(self.opts:get().jobs)}) end
  self.running = true
  self.build_status = build_states.running
  local cmd = command:new({log_filename = self.log_filename, show_command_logs = self.opts:get().show_command_logs})
  cmd:execute(args, "Build", function(status) self:_on_command_exit(status) end)
end

function cmake:clean_from_preset()
  self:get_preset("build", function(preset_name)
    local args = {"--build", "--preset", preset_name, "--target", "clean"}
    local cmd = command:new({log_filename = self.log_filename, show_command_logs = self.opts:get().show_command_logs})
    self.running = true
    cmd:execute(args, "Clean using preset " .. preset_name, function(status) self:_on_command_exit(status) end)
  end)
end

function cmake:clean()
  if self.running then
    notification.notify("CMake already running", vim.log.levels.WARN)
    return
  end
  if next(self.preset_list["build"]) ~= nil then
    self:clean_from_preset()
    return
  else
    vim.fn.mkdir(self.opts:get().build_folder, "p")
  end

  local args = {"--build", self.opts:get().build_folder, "--target", "clean"}
  local cmd = command:new({log_filename = self.log_filename, show_command_logs = self.opts:get().show_command_logs})
  self.running = true
  cmd:execute(args, "Clean", function(status) self:_on_command_exit(status) end)
end

function cmake:show_log()
  local buf, _ = window.centered_window()

  -- press 'q' or 'esc' to close window
  for _, key in ipairs({'q', '<esc>'}) do
    vim.api.nvim_buf_set_keymap(buf, 'n', key, '<cmd>close<cr>', {nowait = true, noremap = true, silent = true})
  end

  vim.api.nvim_command("$read" .. self.log_filename)
  vim.api.nvim_set_option_value("readonly", true, {buf = buf})
  vim.api.nvim_set_option_value("modified", false, {buf = buf})

end

function cmake:check_auto_build()
  if not self.opts:get().auto_build or self.running then return end
  if next(self.preset_list["build"]) == nil or self.selected_preset["build"] ~= nil then
    self:build()
  else
    -- only if there is no user interaction the auto_build is enabled
    notification.notify("CMake auto build skipped", vim.log.levels.INFO)
  end
end

function cmake:debug_target()
  if self.fileapi == nil then
    notification.notify("Missing target configuration, please execute CMakeConfigure first", vim.log.levels.WARN)
    return
  end
  utils.select_from_list("Select target to run", self.fileapi:target_names(), function(name)
    if name == nil then return end
    local target = self.fileapi.targets[name]

    ntf.notify("Debug " .. name, vim.log.levels.INFO)

    local dap_config = {
      args = {},
      cwd = vim.uv.cwd(),
      program = target.artifact,
      request = "launch",
      name = "Debug " .. name,
      type = self.opts:get().dap_adapter
    }

    dap.run(dap_config)
  end)
end

function cmake:run_target()
  if self.fileapi == nil then
    notification.notify("Missing target configuration, please execute CMakeConfigure first", vim.log.levels.WARN)
    return
  end
  utils.select_from_list("Select target to run", self.fileapi:target_names(), function(name)
    if name == nil then return end
    local target = self.fileapi.targets[name]
    vim.cmd("!" .. target.artifact)
  end)
end

return cmake

