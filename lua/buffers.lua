--------------------------------
-- A collection of buffers
--------------------------------
Buffers = {}

function Buffers:new(n)
  local t = n or {length = 0, buffers = {}}
  self.__index = self
  return setmetatable(t, self)
end

function Buffers.__add(a, b)
  return a.length + b.length
end

-- Take a section and remove a buffer arbitrarily
-- reducing the length is very important as otherwise we don't know
-- a section is actually smaller now
function Buffers:drop(index)
  if self.buffers[index] ~= nil then
    self.length = self.length - self.buffers[index].length
    table.remove(self.buffers, index)
    return self
  end
end

function Buffers:add(buf)
  table.insert(self.buffers, buf)
  self.length = self.length + buf.length
end

--------------------------------
-- A single buffer
--------------------------------

Buffer = {}

function Buffer:new(n)
  local new = n or {
    id = nil,
    component = nil,
    current = false,
    ordinal = nil,
    length = 0
  }
  self.__index = self
  return setmetatable(new, self)
end
