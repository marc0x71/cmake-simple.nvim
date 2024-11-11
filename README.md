# cmake-simple.nvim
Simple NeoVim plugin for CMake/CTest integration

## Motivation
If you are looking for a simple solution to run CMake/CTest commands without opening a new terminal and also run tests in debug (with `nvim-dap`), this plugin might be for you! 😎

## Requirements

This plugin requires:

- [`fidget.nvim`](https://github.com/j-hui/fidget.nvim) to show notification messages and execution progress.
- [`nvim-dap`](https://github.com/mfussenegger/nvim-dap) for debugging tests

You also must have `cmake` and `ctest` installed on your local machine

## Installation

You can use your preferred package manager, the following example is based on
[`lazy.nvim`](https://github.com/folke/lazy.nvim):

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
        dap_adapter = "gdb"
    },
    keys = {
      { '<leader>mc',  '<cmd>CMakeConfigure<cr>', desc = "Configure project" },
      { '<leader>mb',  '<cmd>CMakeBuild<cr>',     desc = "Build project" },
      { '<leader>mC',  '<cmd>CMakeClean<cr>',     desc = "Clean project" },
      { '<leader>ml',  '<cmd>CMakeLog<cr>',       desc = "Show last log" },
      { '<leader>mt',  '<cmd>CTestCases<cr>',     desc = "Show tests" }
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
    dap_adapter = "gdb"
}
```

## CTest

Using `cmake-simple` you can easly execute test using the following keyboard shortcut in the `CTestCases` command :

- `R` - execute all tests
- `r` - execute selected test
- `d` - debug selected test
- `l` - show last log of selected test
- `<CR>` - go to the source code of selected test

Currently only for the following test framework is supported the "go-to" feature:

- [`GTest`](https://github.com/google/googletest)
- [`Catch2`](https://github.com/catchorg/Catch2)

## Troubleshooting

If this plugin isn't working, feel free to make an issue or a pull request.

