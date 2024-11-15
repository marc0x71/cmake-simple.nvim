local function _file_exists(name)
  local f = io.open(name, "r")
  if f ~= nil then
    io.close(f)
    return true
  else
    return false
  end
end

--[[
--http://lua-users.org/wiki/SortedIteration
--
Ordered table iterator, allow to iterate on the natural order of the keys of a
table.

Example:
]]

local function __genOrderedIndex(t)
  local orderedIndex = {}
  for key in pairs(t) do table.insert(orderedIndex, key) end
  table.sort(orderedIndex)
  return orderedIndex
end

local function orderedNext(t, state)
  -- Equivalent of the next function, but returns the keys in the alphabetic
  -- order. We use a temporary ordered key table that is stored in the
  -- table being iterated.

  local key = nil
  -- print("orderedNext: state = "..tostring(state) )
  if state == nil then
    -- the first time, generate the index
    t.__orderedIndex = __genOrderedIndex(t)
    key = t.__orderedIndex[1]
  else
    -- fetch the next value
    for i = 1, vim.tbl_count(t.__orderedIndex) do
      if t.__orderedIndex[i] == state then key = t.__orderedIndex[i + 1] end
    end
  end

  if key then return key, t[key] end

  -- no more value to return, cleanup
  t.__orderedIndex = nil
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

  orderedPairs = function(t)
    -- Equivalent of the pairs() function on tables. Allows to iterate
    -- in order
    return orderedNext, t, nil
  end
}

return M

