local window = require('cmake-simple.lib.window')
local utils = require('cmake-simple.lib.utils')
local ntf = require('cmake-simple.lib.notification')
local storage = require('cmake-simple.lib.storage')

local M = {config_buf = nil, config_win = nil, callback = nil, closing = false}

M._close = function()
  if M.closing then return end
  M.closing = true

  if M.config_buf ~= nil and vim.api.nvim_buf_is_valid(M.config_buf) then
    vim.api.nvim_buf_delete(M.config_buf, {force = true})
  end
  if M.config_win ~= nil and vim.api.nvim_win_is_valid(M.config_win) then vim.api.nvim_win_close(M.config_win, true) end

  M.config_win = nil
  M.config_buf = nil
  M.closing = false
end

M._save = function()
  if M.closing then return end
  M.closing = true

  if M.config_buf == nil or not vim.api.nvim_buf_is_valid(M.config_buf) then return end

  local lines = vim.api.nvim_buf_get_lines(M.config_buf, 0, -1, true)
  local content = table.concat(lines, " ")
  local valid, opts = pcall(load, ("return " .. content))
  if not valid or opts == nil or opts() == nil then
    ntf.notify("Invalid configuration", vim.log.levels.ERROR)
    return
  end

  storage.save(vim.uv.cwd(), content)

  ntf.notify("Configuration saved", vim.log.levels.INFO)

  M.closing = false

  M.callback(opts())
end

local function _show_config(current, callback)
  if M.config_buf ~= nil then M._close() end

  local current_content = utils.split(vim.inspect(current), "\n")

  M.config_buf, M.config_win = window.popup("CMakeSimple local config")

  vim.api.nvim_buf_set_name(M.config_buf, "cmakesimple-config")
  vim.api.nvim_set_option_value("filetype", "cmakesimple", {buf = M.config_buf})
  vim.api.nvim_set_option_value("buftype", "acwrite", {buf = M.config_buf})
  vim.api.nvim_set_option_value("bufhidden", "delete", {buf = M.config_buf})

  vim.keymap.set("n", "q", function() M._close() end, {buffer = M.config_buf, silent = true})
  vim.keymap.set("n", "<Esc>", function() M._close() end, {buffer = M.config_buf, silent = true})

  vim.api.nvim_create_autocmd("BufWriteCmd", {
    buffer = M.config_buf,
    callback = function()
      M._save()
      vim.schedule(function() M._close() end)
    end
  })
  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = M.config_buf,
    callback = function() vim.schedule(function() M._close() end) end
  })
  -- vim.api.nvim_create_autocmd("BufLeave", {buffer = M.config_buf, callback = M._close})
  vim.cmd(string.format("autocmd BufModifiedSet <buffer=%s> set nomodified", M.config_buf))

  vim.api.nvim_buf_set_lines(M.config_buf, 0, #current_content, false, current_content)

  M.callback = callback
end

M.get_config = function(default)
  local content = storage.load(vim.uv.cwd())
  local valid, saved = pcall(load, ("return " .. content))
  if not valid or saved == nil or saved() == nil then
    ntf.notify("Invalid saved configuration", vim.log.levels.ERROR)
    return default
  end
  local saved_opts = saved()
  if saved_opts == nil then return default end
  return vim.tbl_extend('force', default, saved_opts)
end

M.show_config = function(current, callback) _show_config(current, callback) end

return M
