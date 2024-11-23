local default_settings = {
  build_folder = "build",
  config_type = "Debug",
  jobs = 2,
  dap_adapter = "gdb",
  clean_first = false,
  show_command_logs = false,
  auto_build = false
}

local settings = {}

function settings:new()
  local o = {inner = vim.deepcopy(default_settings)}
  setmetatable(o, self)
  self.__index = self
  return o
end

function settings:update(opts) self.inner = vim.tbl_deep_extend("force", self.inner, opts or {}) end

function settings:get() return self.inner end

return settings

