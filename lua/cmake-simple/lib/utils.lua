local function _file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

local M = {
  file_exists = function(name) return _file_exists(name) end,

  get_path = function(path, sep)
    sep = sep or '/'
    return path:match("(.*" .. sep .. ")")
  end,

  read_all = function(filename)
    local f = io.open(filename, "r")
    if f == nil then return nil end
    local content = f:read("*a")
    f:close()
    return content
  end,

  create_window = function()
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

    -- press 'q' or 'esc' to clone window
    for _, key in ipairs({'q', '<esc>'}) do
      vim.api.nvim_buf_set_keymap(buf, 'n', key, '<cmd>close<cr>', {nowait = true, noremap = true, silent = true})
    end
    return buf, win
  end,

  buf_append_colorized = function(buf, content, content_type)
    vim.api.nvim_buf_set_lines(buf, -1, -1, false, {content})
    local row = vim.api.nvim_buf_line_count(buf)
    local highlight = 'Normal'
    if content_type == "err" then
      highlight = 'ErrorMsg'
    elseif content_type == "start" or content_type == "end" then
      highlight = 'Title'
    end
    vim.api.nvim_buf_add_highlight(buf, -1, highlight, row - 1, 0, content:len())
    return row
  end

}

return M

