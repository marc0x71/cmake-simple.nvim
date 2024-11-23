# cmake-simple.nvim
Simple NeoVim plugin for CMake/CTest integration

![Screenshot](https://github.com/marc0x71/cmake-simple.nvim/blob/main/images/cmake-simple-screenshot.png?raw=true)

## Motivation
If you are looking for a simple solution to run CMake/CTest commands without opening a new terminal and also run targets and tests in debug (with `nvim-dap`), this plugin might be for you! 😎

It's **simple** to make life **simple**, and it's useful enough to make it essential 😀

## Description

`CMakeSimple` is a NeoVim plugin that will allow you (easily) to manage your workflow with CMake and CTest directly from your **favorite** editor.

You will be able to perform the configure of `CMake` project simply by pressing a button, as well as compile your project or maybe run your tests thanks to the help of `CTest`.

You will also be able to debug your tests, and even your applications, directly from NeoVim thanks to the help of `nvim-dap`, or perform the compilation of your code **automagically** when you save your changes!

**So what are you waiting for? Install it and enjoy!**

## Requirements

This plugin requires:

- [`fidget.nvim`](https://github.com/j-hui/fidget.nvim) to show notification messages and execution progress.
- [`nvim-dap`](https://github.com/mfussenegger/nvim-dap) for debugging targets and tests
- [`treesitter`](https://github.com/nvim-treesitter/nvim-treesitter) for tests source code analysis
- [`telescope`](https://github.com/nvim-telescope/telescope.nvim) used for UI selections
- [`plenary`](https://github.com/nvim-lua/plenary.nvim) used also for unit tests

You also must have `cmake` and `ctest` installed on your local machine

## Installation

You can use your preferred package manager, the following example is based on [`lazy.nvim`](https://github.com/folke/lazy.nvim):

```lua
{
    'marc0x71/cmake-simple.nvim',
    name = "cmake-simple",
    dependencies = {
      {
        "j-hui/fidget.nvim",
        config = function()
          require("fidget").setup({
            notification = {
              window = {
                winblend = 0,
              },
            }
          })
        end,
      },
    },
    lazy = false,
    opts = {
        build_folder = "build", 
        jobs = 2, 
        dap_adapter = "gdb",
        clean_first = false,
        show_command_logs = false,
        auto_build = false
    },
    keys = {
      { '<leader>mc',  '<cmd>CMakeConfigure<cr>',            desc = "Configure project" },
      { '<leader>mb',  '<cmd>CMakeBuild<cr>',                desc = "Build project" },
      { '<leader>mC',  '<cmd>CMakeClean<cr>',                desc = "Clean project" },
      { '<leader>ml',  '<cmd>CMakeLog<cr>',                  desc = "Show last log" },
      { '<leader>mt',  '<cmd>CTestCases<cr>',                desc = "Show tests" },
      { '<leader>mL',  '<cmd>CMakeToogleCommandLog<cr>',     desc = "Toogle command log window" },
      { '<leader>mr',  '<cmd>CMakeRun<cr>',                  desc = "Execute target" },
      { '<leader>md',  '<cmd>CMakeDebug<cr>',                desc = "Execute target in debug" },
      { '<leader>mT',  '<cmd>CRunTestCases<cr>',             desc = "Execute all tests" },
      { '<leader>ms',  '<cmd>CMakeSettings<cr>',             desc = "Change CMakeSimple settings" },
      { '<leader>mS',  '<cmd>CMakeSelectConfType<cr>',       desc = "Select CMake configuration type" }
    }
}
```

## Configuration

`cmake-simple` comes with the following default configuration:

```lua
{
    -- Path used to build the CMake project
    build_folder = "build", 
    -- How many jobs can be used for building and running all tests
    jobs = 2, 
    -- The dap adapter used for debugging
    dap_adapter = "gdb",
    -- Clean targets before build
    clean_first = false,
    -- Show always cmake command log window
    show_command_logs = false,
    -- Automatically build project if a source file has been changed
    auto_build = false
}
```

You can overwrite using `setup` function or via `opts` if you are using [`lazy.nvim`](https://github.com/folke/lazy.nvim):

## Available Commands

|Command|Description|
|-|-|
|CMakeInit|Initialize CMake project and reset selected presets. CMakeLists.txt *must be* present in he current folder. This command is executed automatically when current folder change|
|CMakeConfigure|Execute `cmake` command to configure the project|
|CMakeBuild|Execute `cmake` command to build the project|
|CMakeClean|Execute `cmake` command to clean the project|
|CMakeLog|Show last execution log|
|CTestCases|Show found test cases (show next paragraph for available shortcuts)|
|CMakeToogleCommandLog|Hide/Show log windows when `cmake` command is executed |
|CRunTestCases|Run all CTest test cases|
|CMakeRun|Run target|
|CMakeDebug|Run target in debug (using DAP)|
|CMakeSettings|Change CMakeSimple setting for current project|
|CMakeSelectConfType|Select CMake configuration type|

## CTest

Using `cmake-simple` you can easly execute test using the following keyboard shortcut in the `CTestCases` command :

- `R` - execute all tests
- `r` - execute selected test
- `d` - debug selected test
- `l` - show last log of selected test
- `<CR>` - go to the source code of selected test
- `<F5>` - refresh testcases without changing selected test preset
- `q` or `<ESC>` - close the testcases window

Currently only for the following test framework is supported the "go-to" feature:

- [`GTest`](https://github.com/google/googletest)
- [`Catch2`](https://github.com/catchorg/Catch2)

## Status line

If you are using ['lualine.nvim'](https://github.com/nvim-lualine/lualine.nvim) you can add an indicator 
that will show if the project has been build or not, for example:

![Status line example](https://github.com/marc0x71/cmake-simple.nvim/blob/main/images/statusbar.png?raw=true)

```lua
return {
    'nvim-lualine/lualine.nvim',
    dependencies = {'nvim-tree/nvim-web-devicons'},
    config = function()
        ...
        local cmakesimple = require 'cmake-simple'
        require('lualine').setup({
            ...
            sections = {
                lualine_x = {
                    {
                        cmakesimple.build_status,
                        cond = cmakesimple.build_status_available
                    }
                }
            }
            ...
        })
    end
}
```

## Troubleshooting

If this plugin isn't working, feel free to make an issue or a pull request.

