local utils = require("cmake-simple.lib.utils")
local scandir = require("plenary.scandir")

local fileapi = {}

function fileapi:new(opts)
  local o = {
    opts = opts,
    targets = {},
    query_path = opts.path .. "/.cmake/api/v1/query",
    reply_path = opts.path .. "/.cmake/api/v1/reply"
  }

  setmetatable(o, self)
  self.__index = self

  return o
end

function fileapi:init_model()
  os.execute("mkdir -p " .. self.query_path)
  os.execute("mkdir -p " .. self.reply_path)
  utils.create_file(self.query_path .. "/codemodel-v2")
end

function fileapi:_load_codemodel(filename)
  local codemodel = utils.read_json_file(self.reply_path .. "/" .. filename)
  for _, conf_target in pairs(codemodel.configurations[1].targets) do
    local target_info = utils.read_json_file(self.reply_path .. "/" .. conf_target.jsonFile)
    if target_info.type == "EXECUTABLE" or target_info.type == "STATIC_LIBRARY" then
      local sources = {}
      for _, source in pairs(target_info.sources) do table.insert(sources, source.path) end
      self.targets[conf_target.name] = {
        name = conf_target.name,
        type = target_info.type,
        artifact = self.opts.path .. "/" .. target_info.artifacts[1].path,
        sources = sources,
        codemodel = conf_target.jsonFile
      }
    end
  end
end

function fileapi:_load_index(filename)
  self.targets = {}
  local codemodels = {}
  local index = utils.read_json_file(filename)
  for _, v in pairs(index.reply) do if v.kind == "codemodel" then table.insert(codemodels, v.jsonFile) end end
  for _, codemodel in pairs(codemodels) do self:_load_codemodel(codemodel) end
end

function fileapi:update()
  scandir.scan_dir_async(self.reply_path, {
    respect_gitignore = false,
    silent = true,
    search_pattern = {".*index-.*json$"},
    on_insert = function(filename) pcall(self._load_index, self, filename) end
  })
end

function fileapi:target_names()
  local list = {}
  for k, v in pairs(self.targets) do if v["type"] == "EXECUTABLE" then table.insert(list, k) end end
  return list
end

return fileapi

