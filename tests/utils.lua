local M = {}

function M.vim_enter()
  vim.cmd("doautocmd VimEnter")
end

local MockBuffer = {}

function MockBuffer:new(o)
  self.__index = self
  setmetatable(o, self)
  o.type = "buffer"
  return o
end

function MockBuffer:as_buffer()
  return self
end

M.MockBuffer = MockBuffer

return M
