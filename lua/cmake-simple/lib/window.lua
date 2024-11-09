local M = {
  centered_window = function()
    local buf = vim.api.nvim_create_buf(false, true)

    vim.api.nvim_set_option_value('bufhidden', 'wipe', {buf = buf})

    local width = vim.api.nvim_get_option_value("columns", {scope = "global"})
    local height = vim.api.nvim_get_option_value("lines", {scope = "global"})

    local win_height = math.ceil(height * 0.8 - 4)
    local win_width = math.ceil(width * 0.8)

    local row = math.ceil((height - win_height) / 2 - 1)
    local col = math.ceil((width - win_width) / 2)

    local opts = {
      style = "minimal",
      relative = "editor",
      width = win_width,
      height = win_height,
      row = row,
      col = col,
      border = "rounded"
    }

    local win = vim.api.nvim_open_win(buf, true, opts)

    return buf, win
  end,

  panel_window = function()
    local buf = vim.api.nvim_create_buf(false, true)

    local width = vim.api.nvim_get_option_value("columns", {scope = "global"})
    local win_width = math.min(math.ceil(width * 0.1), 30)

    vim.api.nvim_set_option_value('bufhidden', 'wipe', {buf = buf})

    local opts = {
      style = "minimal",
      split = "right",
      win = 0,
      width = win_width,
    }
    local win = vim.api.nvim_open_win(buf, true, opts)
    vim.api.nvim_buf_set_lines(buf, -1, -1, true, {})

    return buf, win
  end
}

return M
