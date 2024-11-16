local notification = require('cmake-simple.lib.notification')

local function _init_commands()
  -- Autocommand
  local cmake_simple_augroup = vim.api.nvim_create_augroup("cmakesimpleaugroup", {clear = true})

  vim.api.nvim_create_autocmd({"VimEnter", "DirChanged"}, {
    callback = function(_) require('cmake-simple').initialize() end,
    group = cmake_simple_augroup
  })

  vim.api.nvim_create_autocmd({"BufWritePost"}, {
    pattern = {"*.c", "*.h", "*.cc", "*.cpp", "*.C", "*.hpp", "*.jnl"},
    callback = function(_) require('cmake-simple').check_auto_build() end,
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

  vim.api.nvim_create_user_command("CMakeToogleCommandLog", function() require('cmake-simple').toogle_command_log() end,
                                   { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake show log during commands"
  })

  vim.api.nvim_create_user_command("CTestCases", function() require('cmake-simple').testcases() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CTest show testcases"
  })
end

local M = {}

M.setup = function(opts) require("cmake-simple.app").get():update(opts) end

M.initialize = function() require("cmake-simple.app").get():initialize() end

M.configure = function() require("cmake-simple.app").get():configure() end

M.build = function() require("cmake-simple.app").get():build() end

M.clean = function() require("cmake-simple.app").get():clean() end

M.show_log = function() require("cmake-simple.app").get():show_log() end

M.toogle_command_log = function()
  local show = not require("cmake-simple.app").get().opts.inner.show_command_logs
  if show then
    notification.notify("Enabled command log", vim.log.levels.INFO)
  else
    notification.notify("Disabled command log", vim.log.levels.INFO)
  end
  require("cmake-simple.app").get():update({show_command_logs = show})
end

M.testcases = function() require("cmake-simple.app").get():testcases() end

M.check_auto_build = function() require("cmake-simple.app").get():check_auto_build() end

M.build_status = function() return "CMake " .. require("cmake-simple.app").get():build_status() end

M.build_status_available = function() return require("cmake-simple.app").get():build_status_available() end

_init_commands()

return M

