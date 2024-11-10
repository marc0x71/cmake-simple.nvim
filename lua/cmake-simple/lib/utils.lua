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
    vim.api.nvim_buf_set_lines(buf, -1, -1, true, {content})
    local row = vim.api.nvim_buf_line_count(buf)
    local highlight = 'Normal'
    if content_type == "err" or content_type == "fail" then
      highlight = 'DiagnosticError'
    elseif content_type == "skipped" then
      highlight = 'DiagnosticInfo'
    elseif content_type == "run" then
      highlight = 'DiagnosticOk'
    elseif content_type == "start" or content_type == "end" then
      highlight = 'Title'
    end
    vim.api.nvim_buf_add_highlight(buf, -1, highlight, row - 1, 0, content:len())
    return row
  end,

  idict = function(tbl)
    local keys = {}
    for k in next, tbl do table.insert(keys, k) end
    return function(_, i)
      i = i + 1
      local k = keys[i]
      if k then return i, k, tbl[k] end
    end, keys, 0
  end,

  trim = function(s)
    if s == nil then return "" end
    return (s:gsub("^%s*(.-)%s*$", "%1"))
  end,

}

return M

