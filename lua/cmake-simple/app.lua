local utils = require('cmake-simple.lib.utils')
local settings = require('cmake-simple.settings')
local notification = require('cmake-simple.lib.notification')

local M = {}
local instance = nil

local function _cmakefiles_exists(silent)
  silent = silent or false
  if not utils.file_exists("CMakeLists.txt") then
    if not silent then notification.notify("Initialization not completed", vim.log.levels.ERROR) end
    return false
  end
  return true
end

function M:new(opts)
  local log_filename = os.tmpname()
  local cwd = vim.uv.cwd()
  local o = {
    opts = opts,
    cwd = cwd,
    log_filename = log_filename,
    cmake_instance = require('cmake-simple.cmake'):new(opts, log_filename),
    ctest_instance = require('cmake-simple.ctest'):new(opts)
  }
  setmetatable(o, self)
  self.__index = self
  return o
end

function M:update(opts) self.opts:update(opts) end

function M.get()
  if not instance then instance = M:new(settings:new()) end
  return instance
end

function M:initialize()
  local cwd = vim.uv.cwd()
  if not utils.file_exists("CMakeLists.txt") then return end

  notification.notify("CMakeLists.txt found in " .. cwd, vim.log.levels.INFO)

  self.cmake_instance:load_presets()
  self.ctest_instance:load_presets()
end

function M:configure() if _cmakefiles_exists() then self.cmake_instance:configure() end end

function M:build() if _cmakefiles_exists() then self.cmake_instance:build() end end

function M:clean() if _cmakefiles_exists() then self.cmake_instance:clean() end end

function M:show_log() if _cmakefiles_exists() then self.cmake_instance:show_log() end end

function M:check_auto_build() if _cmakefiles_exists() then self.cmake_instance:check_auto_build() end end

function M:testcases() if _cmakefiles_exists(true) then self.ctest_instance:testcases() end end

function M:run_testcases()
  if _cmakefiles_exists(true) then self.ctest_instance:testcases(function() self.ctest_instance:run_all_test() end) end
end

function M:build_status()
  if _cmakefiles_exists(true) then
    return "  󰙄 " .. self.cmake_instance.opts.inner.config_type .. "    Build " .. self.cmake_instance.build_status
  else
    return ""
  end
end

function M:build_status_available() return _cmakefiles_exists(true) end

function M:run_target() if _cmakefiles_exists() then self.cmake_instance:run_target() end end

function M:debug_target() if _cmakefiles_exists() then self.cmake_instance:debug_target() end end

function M:select_conf_type() if _cmakefiles_exists() then self.cmake_instance:select_conf_type() end end

return M

