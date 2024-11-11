local function _init_commands()
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

local M = {}

M.setup = function(opts) require("cmake-simple.app").get():update(opts) end

M.initialize = function() require("cmake-simple.app").get():initialize() end

M.configure = function() require("cmake-simple.app").get():configure() end

M.build = function() require("cmake-simple.app").get():build() end

M.clean = function() require("cmake-simple.app").get():clean() end

M.show_log = function() require("cmake-simple.app").get():show_log() end

M.testcases = function() require("cmake-simple.app").get():testcases() end

_init_commands()

return M

