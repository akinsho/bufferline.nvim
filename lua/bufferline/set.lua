---@class Set
---@field private values table<string, number>
local Set = {}

---@param list integer[]
---@return Set
function Set:new(list)
  list = list or {}
  local set = { values = {} }
  for index, l in ipairs(list) do
    set.values[tostring(l)] = index
  end
  setmetatable(set, self)
  self.__index = self
  return set
end

---@param item number
---@param index number
function Set:add(item, index)
  if not self.values[item] then
    self.values[tostring(item)] = index
  end
end

---@param item number
---@return boolean
function Set:has(item)
  return self.values[tostring(item)] ~= nil
end

---@param item number
function Set:remove(item)
  if self.values[item] then
    self.values[item] = nil
  end
end

---@return number[]
function Set:get_all()
  local result = {}
  for key, value in pairs(self.values) do
    table.insert(result, value, tonumber(key))
  end
  return result
end

---@param list number[]
function Set:add_all(list)
  for index, l in ipairs(list) do
    self:add(l, #self.values + index)
  end
end

---The list of items that the set has in common with the list
---@param list number[]
function Set:intersection(list)
  local result = {}
  local set_b = Set:new(list)
  local items = self:get_all()
  for _, item in ipairs(items) do
    if set_b:has(item) then
      table.insert(result, item)
    end
  end
  return result
end

return Set
