local M = {}

--------------------------------
-- A collection of visual tabs
--------------------------------

--- A visual tab in the tabline i.e. not necessarily representative of a vim tab or buffer
---@class ViewTab
---@field length number
---@field component function
local ViewTab = {}

function ViewTab:new(t)
  self.__index = self
  return setmetatable(t, self)
end

-- TODO: this should be handled based on the type of entity
-- e.g. a buffer should report if it's current but other things shouldn't
function ViewTab:current()
  return (self and self.current) and self.current() or false
end

---Convert a buffer to a ViewTab
---@param buf Buffer
function ViewTab:from_buffer(buf)
  return ViewTab:new({
    current = function()
      return buf:current()
    end,
    item = buf,
  })
end

---@class ViewTabs
---@field items ViewTab[]
---@field length number
local ViewTabs = {}

---create a segment of view tabs
---@param n ViewTabs
---@return ViewTabs
function ViewTabs:new(n)
  local t = n or { length = 0, items = {} }
  self.__index = self
  return setmetatable(t, self)
end

function ViewTabs.__add(a, b)
  return a.length + b.length
end

-- Take a section and remove an item arbitrarily
-- reducing the length is very important as otherwise we don't know
-- a section is actually smaller now
function ViewTabs:drop(index)
  if self.items[index] ~= nil then
    self.length = self.length - self.items[index].length
    table.remove(self.items, index)
    return self
  end
end

function ViewTabs:add(item)
  table.insert(self.items, item)
  self.length = self.length + item.length
end

M.ViewTabs = ViewTabs
M.ViewTab = ViewTab

return M
