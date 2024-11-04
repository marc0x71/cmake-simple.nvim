local utils = require('cmake-simple.lib.utils')

local xml_tag = {
  BEFORE_TAG = "([^<]*)",
  TAG = "<([^>]+)>",
  TAG_NAME = "(/?[%w-_:]+)%s*(.*)",
  TAG_ATTR = "%s*([%w-_:]+)=['\"]([^'\"]+)['\"]"
}

local function next_content(xml_str, pos)
  local _start, _end = string.find(xml_str, xml_tag.BEFORE_TAG, pos)
  if _start == nil then return pos, nil end
  return _end, string.sub(xml_str, _start, _end)
end

local function next_element(xml_str, pos)
  local _start, _end = string.find(xml_str, xml_tag.TAG, pos)
  if _start == nil then return pos, nil end
  return _end + 1, string.sub(xml_str, _start + 1, _end - 1):gsub("%s+", " ")
end

local function attrs_parse(attr_str)
  local result = {}
  for name, value in string.gmatch(attr_str, xml_tag.TAG_ATTR) do result[name] = value end
  return result
end

local function element_parse(tag_str)
  local self_closing = utils.starts_with(tag_str, "?")
  local end_tag = false
  local name, other = string.match(tag_str, xml_tag.TAG_NAME)
  if name == nil then return nil end
  name = utils.trim(name)
  other = utils.trim(other)
  if utils.starts_with(name, "/") then
    end_tag = true
    name = name:sub(2)
  elseif utils.ends_with(other, "/") then
    self_closing = true
    other = other:sub(1, -2)
  end
  local attrs = attrs_parse(other)
  return name, attrs, self_closing, end_tag
end

local function elements_parse(xml_str, pos)

  local result = {}
  pos = pos or 0

  while true do
    local element;
    pos, _ = next_content(xml_str, pos)
    pos, element = next_element(xml_str, pos)
    if element == nil then break end
    local name, attrs, self_closing, end_tag = element_parse(element)
    if name ~= "xml" then
      if self_closing then
        table.insert(result, {"name", name, attrs = attrs})
      elseif end_tag then
        return result, pos
      elseif not self_closing then
        local childs, content
        pos, content = next_content(xml_str, pos)
        childs, pos = elements_parse(xml_str, pos)
        table.insert(result, {name = name, attrs = attrs, children = childs, content = content})
      end
    end
  end

  return result, pos
end

return function (xml_str)
  local t, _ = elements_parse(xml_str)
  return t
end

