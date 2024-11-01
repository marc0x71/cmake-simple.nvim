# cmake-simple.nvim
Simple NeoVim plugin for CMake integration

## Installation

This plugin requires [`fidget.nvim`](https://github.com/j-hui/fidget.nvim) to show notification messages and execution progress.


The following example is based on
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
    init = function ()
      require('cmake-simple')
    end,
    keys = {
      { '<leader>mc',  '<cmd>CMakeConfigure<cr>',  desc="Configure project" },
      { '<leader>mb',  '<cmd>CMakeBuild<cr>',  desc="Build project" },
      { '<leader>mC',  '<cmd>CMakeClean<cr>',  desc="Clean project" },
      { '<leader>ml',  '<cmd>CMakeLog<cr>',  desc="Show last log" },
    }

}
```
## Configuration

TODO

