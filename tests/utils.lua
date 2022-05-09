local M = {}

local fn = vim.fn

local MockBuffer = {}

function M.tabline_from_components(components)
  local str = ""
  for _, c in ipairs(components) do
    for _, v in ipairs(c) do
      str = str .. (v.text or "")
    end
  end
  return str
end

---helper to find text in a Segment[]
---@param component Segment[]
---@param text string
---@return boolean
function M.find_text(component, text)
  local found = false
  for _, item in ipairs(component) do
    if item.text == text then
      found = true
    end
  end
  return found
end

function MockBuffer:new(o)
  self.__index = self
  setmetatable(o, self)
  o.type = "buffer"
  return o
end

function MockBuffer:as_element()
  return self
end

---@param name string
---@param state BufferlineState
---@return TabElement
function M.find_buffer(name, state)
  for _, component in ipairs(state.components) do
    local element = component:as_element()
    if fn.matchstr(element.name, name) ~= "" then
      return component
    end
  end
end

M.MockBuffer = MockBuffer

return M
