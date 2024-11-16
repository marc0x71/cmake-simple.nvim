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

return M

