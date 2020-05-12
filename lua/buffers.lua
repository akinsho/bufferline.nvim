Buffers = {}

function Buffers:new(n)
  local _t = n or {length = 0, buffers = {}}
  self.__index = self
  return setmetatable(_t, self)
end

function Buffers.__add(a, b)
  return a.length + b.length
end

function Buffers.__concat(a, b)
  local new = {}
  vim.list_extend(new, a.buffers)
  vim.list_extend(new, b.buffers)
  return new
end

function Buffers:add(buf)
  table.insert(self.buffers, buf)
  self.length = self.length + buf.length
end
