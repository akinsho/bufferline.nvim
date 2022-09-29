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

function M.reload(module)
  package.loaded[module] = nil
  return require(module)
end

---helper to find text in a Segment[]
---@param component Segment[]
---@param text string
---@return boolean
function M.find_text(component, text)
  local found = false
  for _, item in ipairs(component) do
    if item.text == text then found = true end
  end
  return found
end

function MockBuffer:new(o)
  self.icon = o.icon or ""
  self.__index = self
  setmetatable(o, self)
  o.type = "buffer"
  return o
end

function MockBuffer:is_end() return vim.F.if_nil(self.is_end, false) end

function MockBuffer:current() return vim.F.if_nil(self._is_current, true) end

function MockBuffer:as_element() return self end

function MockBuffer:visibility() return vim.F.if_nil(self._visiblity, 0) end

function MockBuffer:visible() return vim.F.if_nil(self._is_visible, true) end

---@param name string
---@param state BufferlineState
---@return Component?
function M.find_buffer(name, state)
  for _, component in ipairs(state.components) do
    local element = component:as_element()
    if element and fn.matchstr(element.name, name) ~= "" then return component end
  end
end

M.MockBuffer = MockBuffer

return M
