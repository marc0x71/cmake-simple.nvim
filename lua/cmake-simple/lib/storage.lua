local utils = require("cmake-simple.lib.utils")

local M = {path = vim.fn.stdpath("data") .. "/cmakesimple/"}

local function _hash(folder) return vim.fn.sha256(folder) end

M.load = function(folder)
  vim.fn.mkdir(M.path, "p")
  local filename = M.path .. _hash(folder)
  if utils.file_exists(filename) then
    local saved = utils.read_all(filename)
    return saved
  end
  return "{}"

end

M.save = function(folder, content)
  vim.fn.mkdir(M.path, "p")
  local filename = M.path .. _hash(folder)
  utils.create_file(filename, content)
end

return M
