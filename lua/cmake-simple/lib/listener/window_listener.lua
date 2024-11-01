local listener = require('cmake-simple.lib.listener.init')
local utils = require('cmake-simple.lib.utils')

local window_listener = listener:new()

function window_listener:new(action)
  local buf, win = utils.create_window()
  local o = {action = action, win = win, buf = buf}
  setmetatable(o, self)
  self.__index = self
  return o
end

function window_listener:update(content_type, content)
  if not vim.api.nvim_buf_is_valid(self.buf) and not vim.api.nvim_win_is_valid(self.win) then return end
  local row = utils.buf_append_colorized(self.buf, content, content_type)
  vim.api.nvim_win_set_cursor(self.win, {row, 0})
end

function window_listener:success() utils.buf_append_colorized(self.buf, "Success!", "end") end

function window_listener:failure() utils.buf_append_colorized(self.buf, "Failure!", "end") end

return window_listener
