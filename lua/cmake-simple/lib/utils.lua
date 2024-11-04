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
  end,

  trim = function(s)
    if s == nil then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end,

  starts_with = function(s, start) return s:sub(1, #start) == start end,

  ends_with = function(s, ending) return ending == "" or s:sub(-#ending) == ending end

}

return M

