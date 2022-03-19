---@class Set
---@field private values table<string, number>
---@field private list number[]
local Set = {}

---@param list integer[]
---@return Set
function Set:new(list)
  list = list or {}
  local set = { values = {}, list = list }
  for _, l in ipairs(list) do
    set.values[tostring(l)] = true
  end
  setmetatable(set, self)
  self.__index = self
  return set
end

---@param item number
---@param index number
function Set:add(item, index)
  if not self.values[tostring(item)] then
    self.values[tostring(item)] = true
    table.insert(self.list, index or #self.list + 1, item)
  end
end

---@param item number
---@return boolean
function Set:has(item)
  return self.values[tostring(item)] ~= nil
end

function Set:size()
  return #self.list
end

---@param item number
function Set:remove(item)
  if self.values[tostring(item)] then
    self.values[tostring(item)] = nil
    self.list = vim.tbl_filter(function(i)
      return i ~= item
    end, self.list)
  end
end

---@return number[]
function Set:get_all()
  return self.list
end

---@param list number[]
---@param insertion_index number?
function Set:add_all(list, insertion_index)
  for _, item in ipairs(list) do
    self:add(item, insertion_index)
  end
end

---The list of items that the set has in common with the list
---@param list number[]
function Set:intersection(list)
  local result = {}
  local set_b = Set:new(list)
  for _, item in ipairs(self.list) do
    if set_b:has(item) then
      table.insert(result, item)
    end
  end
  return result, set_b
end

function Set:replace_with_intersection(list)
  local intersect, set_b = self:intersection(list)
  self.list = intersect
  self.values = set_b.values
  return self.list
end

return Set
