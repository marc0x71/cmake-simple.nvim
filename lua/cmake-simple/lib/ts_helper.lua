local utils = require('cmake-simple.lib.utils')

-- CATCH2 
-- 
-- expression_statement [8, 0] - [8, 53]
--   call_expression [8, 0] - [8, 53]
--     function: identifier [8, 0] - [8, 9]
--     arguments: argument_list [8, 9] - [8, 53]
--       string_literal [8, 11] - [8, 36]
--         string_content [8, 12] - [8, 35]
--       string_literal [8, 38] - [8, 51]
--         string_content [8, 39] - [8, 50]
--
local catch2_query = [[
(
  (expression_statement 
    (call_expression 
        function: (identifier) @kind (#offset! @kind) (#eq? @kind "TEST_CASE")
        arguments: ( argument_list
            . (string_literal (string_content)) @name
            . (string_literal (string_content))* 
        )
    )
  )
)  
]]

-- GTEST
--
-- function_definition [7, 0] - [36, 1]
--   declarator: function_declarator [7, 0] - [7, 19]
--     declarator: identifier [7, 0] - [7, 4]
--     parameters: parameter_list [7, 4] - [7, 19]
--       parameter_declaration [7, 5] - [7, 10]
--         type: type_identifier [7, 5] - [7, 10]
--       parameter_declaration [7, 12] - [7, 18]
--         type: type_identifier [7, 12] - [7, 18]
local gtest_query = [[
    declarator: (
        function_declarator
          declarator: (identifier) @kind (#offset! @kind) (#any-of? @kind "TEST" "TEST_F" "TEST_P" "TYPED_TEST" "TYPED_TEST_P" "FRIEND_TEST" )
        parameters: (
          parameter_list
            . (comment)*
            . (parameter_declaration type: (type_identifier) !declarator) @namespace
            . (comment)*
            . (parameter_declaration type: (type_identifier) !declarator) @name
            . (comment)*
        )
        (#any-of? @kind "TEST" "TEST_F" "TEST_P" "TYPED_TEST" "TYPED_TEST_P" "FRIEND_TEST")
    )
]]
local queries = {
  -- TODO doctest query 
  -- TODO boost.test query
  gtest_query, catch2_query
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
        local prefix = ""
        if detail["namespace"] ~= nil then prefix = detail["namespace"]:gsub('"', '') .. "." end
        local name = prefix .. detail["name"]:gsub('"', '')
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

