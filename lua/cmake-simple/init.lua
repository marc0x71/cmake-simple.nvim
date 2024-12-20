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

  vim.api.nvim_create_user_command("CMakeRun", function() require('cmake-simple').run_target() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake run target"
  })

  vim.api.nvim_create_user_command("CMakeDebug", function() require('cmake-simple').debug_target() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "CMake run target in Debug"
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

  vim.api.nvim_create_user_command("CRunTestCases", function() require('cmake-simple').run_testcases() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "Run all CTest testcases"
  })

  vim.api.nvim_create_user_command("CMakeSettings", function() require('cmake-simple').settings() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "Change CMakeSimple settings"
  })

  vim.api.nvim_create_user_command("CMakeSelectConfType", function() require('cmake-simple').select_conf_type() end, { -- opts
    nargs = "*",
    bang = true,
    desc = "Select CMake configuration type"
  })
end

local M = {}

M.setup = function(opts)
  local cfg = require("cmake-simple.lib.config")
  require("cmake-simple.app").get():update(cfg.get_config(opts))
end

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

M.run_testcases = function() require("cmake-simple.app").get():run_testcases() end

M.check_auto_build = function() require("cmake-simple.app").get():check_auto_build() end

M.build_status = function() return require("cmake-simple.app").get():build_status() end

M.build_status_available = function() return require("cmake-simple.app").get():build_status_available() end

M.run_target = function() return require("cmake-simple.app").get():run_target() end

M.debug_target = function() return require("cmake-simple.app").get():debug_target() end

M.settings = function()
  local current_opts = require('cmake-simple.app').get().opts.inner
  local cfg = require("cmake-simple.lib.config")
  cfg.show_config(current_opts, function(opts)
    notification.notify("Configuration updated", vim.log.levels.INFO)
    require("cmake-simple.app").get():update(opts)
  end)
end

M.select_conf_type = function() return require("cmake-simple.app").get():select_conf_type() end

_init_commands()

return M

