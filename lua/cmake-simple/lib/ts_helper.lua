local utils = require('cmake-simple.lib.utils')

local queries = {
  -- TODO doctest query 
  -- TODO catch2 query
  -- TODO boost.test query
  -- gtest query
  [[
    declarator: (
        function_declarator
          declarator: (identifier) @kind (#offset! @kind)
        parameters: (
          parameter_list
            . (comment)*
            . (parameter_declaration type: (type_identifier) !declarator) @namespace
            . (comment)*
            . (parameter_declaration type: (type_identifier) !declarator) @name
            . (comment)*
        )
      )
  (#any-of? @kind "TEST" "TEST_F" "TEST_P" "TYPED_TEST" "TYPED_TEST_P" "FRIEND_TEST")
]]
}

local function _extract_from_test(filename)
  local tests = {}

  local content = utils.read_all(filename) or ''
  local language_tree = vim.treesitter.get_string_parser(content, 'cpp')
  local syntax_tree = language_tree:parse()
  local root = syntax_tree[1]:root()
  local found = false
  for _, query_pattern in ipairs(queries) do

    local query = vim.treesitter.query.parse('cpp', query_pattern)

    for _, captures, metadata in query:iter_matches(root, content) do
      found = true
      local detail = {}
      if next(metadata) ~= nil then detail["row"] = metadata[1]["range"][1] + 1 end
      for id, _ in pairs(captures) do
        local name = query.captures[id]
        detail[name] = vim.treesitter.get_node_text(captures[id], content)
      end
      if next(detail) ~= nil then
        local name = detail["namespace"] .. "." .. detail["name"]
        tests[name] = {filename = filename, row = detail["row"]}
      end
    end

    if found then
      -- if found no need to check for other test frameworks
      break
    end
  end

  return tests
end

local M = {extract_test_details = function(filename) return _extract_from_test(filename) end}

return M

