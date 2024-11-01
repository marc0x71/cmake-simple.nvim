local command = require("cmake-simple.lib.command")
local notification = require('cmake-simple.lib.notification')
local utils = require('cmake-simple.lib.utils')

local cmake = {}

function cmake:new(log_filename)

  o = o or {
    cwd = ".",
    build_folder = "build",
    jobs = 2,
    clean_first = true,
    preset_list = {configure = {}, build = {}, test = {}},
    selected_preset = {configure = nil, build = nil, test = nil},
    running = false,
    log_filename = log_filename
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

function cmake:get_preset(name)
  if self.selected_preset[name] == nil then
    vim.ui.select(self.preset_list[name], {prompt = "Select configuration preset"},
                  function(select) self.selected_preset[name] = select end)
  end
  return self.selected_preset[name]
end

function cmake:configure_from_preset()
  local cmd = command:new(self.log_filename)
  local preset_name = self:get_preset("configure")
  local args = {"--preset", preset_name}
  cmd:execute(args, "Configure using preset " .. preset_name, function(status) self.running = false; end)
end

function cmake:configure()
  if self.running then
    notification.notify("CMake already running", "warn")
    return
  end
  self.running = true
  if next(self.preset_list["configure"]) ~= nil then
    self:configure_from_preset()
    return
  end
  local cmd = command:new(self.log_filename)
  local args = {"-S", self.cwd, "-B", self.build_folder}
  cmd:execute(args, "Configure", function(_) self.running = false; end)
end

function cmake:build_from_preset()
  local cmd = command:new(self.log_filename)
  local preset_name = self:get_preset("build")
  local args = {"--build", "--preset", preset_name}
  if self.clean_first then args = vim.list_extend(args, {'--clean-first'}) end
  if self.jobs > 1 then args = vim.list_extend(args, {'-j', tostring(self.jobs)}) end
  cmd:execute(args, "Build using preset " .. preset_name, function(_) self.running = false; end)
end

function cmake:build()
  if self.running then
    notification.notify("CMake already running", "warn")
    return
  end
  self.running = true
  if next(self.preset_list["build"]) ~= nil then
    self:build_from_preset()
    return
  else
    vim.fn.mkdir(self.build_folder, "p")
  end

  local args = {"--build", self.build_folder}
  if self.clean_first then args = vim.list_extend(args, {'--clean-first'}) end
  if self.jobs > 1 then args = vim.list_extend(args, {'-j', tostring(self.jobs)}) end
  local cmd = command:new(self.log_filename)
  cmd:execute(args, "Build", function(_) self.running = false; end)
end

function cmake:clean_from_preset()
  local preset_name = self:get_preset("build")
  local args = {"--build", "--preset", preset_name, "--target", "clean"}
  local cmd = command:new(self.log_filename)
  cmd:execute(args, "Clean using preset " .. preset_name, function(_) self.running = false; end)
end

function cmake:clean()
  if self.running then
    notification.notify("CMake already running", "warn")
    return
  end
  self.running = true
  if next(self.preset_list["build"]) ~= nil then
    self:clean_from_preset()
    return
  else
    vim.fn.mkdir(self.build_folder, "p")
  end

  local args = {"--build", self.build_folder, "--target", "clean"}
  local cmd = command:new(self.log_filename)
  cmd:execute(args, "Clean", function(_) self.running = false; end)
end

function cmake:show_log()
  local buf, win = utils.create_window()
  vim.api.nvim_command("$read" .. self.log_filename)

end

return cmake

