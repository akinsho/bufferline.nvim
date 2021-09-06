local M = {}

--------------------------------
-- A collection of visual tabs
--------------------------------

--- A visual tab in the tabline i.e. not necessarily representative of a vim tab or buffer
---@class TabView
---@field length number
---@field component function
---@field type "'group_end'" | "'group_start'" | "'buffer'"
local TabView = {}

function TabView:new(t)
  self.__index = self
  assert(t.type, 'all view tabs must have a type')
  assert(t.component, 'all view tabs must have a component')
  assert(t.length, 'all view tabs must have a length')
  return setmetatable(t, self)
end

-- TODO: this should be handled based on the type of entity
-- e.g. a buffer should report if it's current but other things shouldn't
function TabView:current()
  return self and self.current() or false
end

---Determine if the current view tab should be treated as the end of a section
---@return boolean
function TabView:end_component()
  return self.type == "group_end"
end

---Convert a buffer to a TabView
---@param buf Buffer
function TabView:from_buffer(buf)
  assert(buf, string.format('A buffer must be passed in: %s', vim.inspect(buf)))
  return TabView:new({
    item = buf,
    type = "buffer",
    length = buf.length,
    component = buf.component,
    current = function()
      return buf:current()
    end,
  })
end

---@param buffers Buffer[]
---@return TabView[]
function M.buffers_to_tabs(buffers)
  local result = {}
  for i, buf in ipairs(buffers) do
    result[i] = TabView:from_buffer(buf)
  end
  return result
end

---@class TabViews
---@field items TabView[]
---@field length number
local TabViews = {}

---create a segment of view tabs
---@param n TabViews
---@return TabViews
function TabViews:new(n)
  local t = n or { length = 0, items = {} }
  self.__index = self
  return setmetatable(t, self)
end

function TabViews.__add(a, b)
  return a.length + b.length
end

-- Take a section and remove an item arbitrarily
-- reducing the length is very important as otherwise we don't know
-- a section is actually smaller now
function TabViews:drop(index)
  if self.items[index] ~= nil then
    self.length = self.length - self.items[index].length
    table.remove(self.items, index)
    return self
  end
end

function TabViews:add(item)
  table.insert(self.items, item)
  self.length = self.length + item.length
end

M.TabViews = TabViews
M.TabView = TabView

return M
