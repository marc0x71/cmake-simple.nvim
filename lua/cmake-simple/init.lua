local utils = require('cmake-simple.lib.utils')
local notification = require('cmake-simple.lib.notification')

local function _init()
  -- Autocommand
  local cmake_simple_augroup = vim.api.nvim_create_augroup("cmakesimpleaugroup", {clear = true})

  vim.api.nvim_create_autocmd({"VimEnter", "DirChanged"}, {
    callback = function(ev) require('cmake-simple').initialize() end,
    group = cmake_simple_augroup
  })

  -- Commands
  vim.api.nvim_create_user_command("CMakeInit", function() require('cmake-simple').initialize() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMakeSimple initialize"
  })

  vim.api.nvim_create_user_command("CMakeConfigure", function() require('cmake-simple').configure() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake configure"
  })

  vim.api.nvim_create_user_command("CMakeBuild", function() require('cmake-simple').build() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake build"
  })

  vim.api.nvim_create_user_command("CMakeClean", function() require('cmake-simple').clean() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake clean"
  })

  vim.api.nvim_create_user_command("CMakeLog", function() require('cmake-simple').show_log() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake show last log"
  })

  vim.api.nvim_create_user_command("CTestCases", function() require('cmake-simple').testcases() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CTest show testcases"
  })
end

local log_filename = os.tmpname()
local M = {cmake_instance = nil, ctest_instance = nil}

M.setup = function(opts) print("Options: ", opts) end

M.initialize = function()
  local cwd = vim.loop.cwd()
  if not utils.file_exists("CMakeLists.txt") then return end

  notification.notify("CMakeLists.txt found in " .. cwd, vim.log.levels.INFO)

  M.cmake_instance = require('cmake-simple.cmake'):new(log_filename)
  M.cmake_instance:load_presets()
  M.ctest_instance = require('cmake-simple.ctest'):new()
  M.ctest_instance:load_presets()
end

M.configure = function()
  if (M.cmake_instance == nil) then
    notification.notify("Initialization not completed", vim.log.levels.ERROR)
  else
    M.cmake_instance:configure()
  end
end

M.build = function()
  if (M.cmake_instance == nil) then
    notification.notify("Initialization not completed", vim.log.levels.ERROR)
  else
    M.cmake_instance:build()
  end
end

M.clean = function()
  if (M.cmake_instance == nil) then
    notification.notify("Initialization not completed", vim.log.levels.ERROR)
  else
    M.cmake_instance:clean()
  end
end

M.show_log = function()
  if (M.cmake_instance == nil) then
    notification.notify("Initialization not completed", vim.log.levels.ERROR)
  else
    M.cmake_instance:show_log()
  end
end

M.testcases = function() 
  if (M.ctest_instance == nil) then
    notification.notify("Initialization not completed", vim.log.levels.ERROR)
  else
    M.ctest_instance:show_testcases()
  end
end

_init()

return M

