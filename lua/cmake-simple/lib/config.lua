local window = require('cmake-simple.lib.window')
local utils = require('cmake-simple.lib.utils')
local ntf = require('cmake-simple.lib.notification')

local M = {config_buf = nil, config_win = nil, border_win = nil, callback = nil}

M._close = function()
  if M.config_buf ~= nil and vim.api.nvim_buf_is_valid(M.config_buf) then vim.api.nvim_buf_delete(M.config_buf, {}) end
  if M.config_win ~= nil and vim.api.nvim_win_is_valid(M.config_win) then vim.api.nvim_win_close(M.config_win, true) end
  if M.border_win ~= nil and vim.api.nvim_win_is_valid(M.border_win) then vim.api.nvim_win_close(M.border_win, true) end

  M.border_win = nil
  M.config_win = nil
  M.config_buf = nil
end

M._on_save = function()
  if M.config_buf == nil or not vim.api.nvim_buf_is_valid(M.config_buf) then return end

  local lines = vim.api.nvim_buf_get_lines(M.config_buf, 0, -1, true)
  local content = table.concat(lines, " ")

  local valid, opts = pcall(load, ("return " .. content))
  if not valid or opts == nil or opts() == nil then
    ntf.notify("Invalid configuration", vim.log.levels.ERROR)
    return
  end

  M._close()

  M.callback(opts())
end

local function _show_config(current, callback)
  if M.config_buf ~= nil then M._close() end

  local current_content = utils.split(vim.inspect(current), "\n")

  local win_opt
  M.config_buf, M.config_win, win_opt = window.popup("CMakeSimple local config")
  M.border_win = win_opt.border.win_id

  vim.api.nvim_buf_set_name(M.config_buf, "cmakesimple-config")
  vim.api.nvim_set_option_value("filetype", "CMakeSimple", {buf = M.config_buf})
  vim.api.nvim_set_option_value("buftype", "acwrite", {buf = M.config_buf})
  vim.api.nvim_set_option_value("bufhidden", "delete", {buf = M.config_buf})

  vim.api.nvim_create_autocmd("BufWriteCmd", {buffer = M.config_buf, callback = M._on_save})
  vim.cmd(string.format("autocmd BufModifiedSet <buffer=%s> set nomodified", M.config_buf))

  vim.api.nvim_buf_set_lines(M.config_buf, 0, #current_content, false, current_content)

  M.callback = callback
end

M.get_config = function(default)
  -- TODO
  return default
end

M.show_config = function(current, callback) _show_config(current, callback) end

return M
