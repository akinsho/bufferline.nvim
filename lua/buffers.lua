local api = vim.api
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
  n.modified = api.nvim_buf_get_option(n.id, 'modified')
  n.filename = vim.fn.fnamemodify(n.path, ":p:t")
  if n.path == "" then n.path = "[No Name]" end

  -- Set icon
  local devicons_loaded = vim.fn.exists('*WebDevIconsGetFileTypeSymbol') > 0
  n.icon = devicons_loaded and vim.fn.WebDevIconsGetFileTypeSymbol(n.path) or ""

  self.__index = self
  return setmetatable(n, self)
end

-- Borrowed this trick from
-- https://github.com/bagrat/vim-buffet/blob/28e8535766f1a48e6006dc70178985de2b8c026d/autoload/buffet.vim#L186
-- If the current buffer in the current window has a matching ID it is ours and so should
-- have the main selected highlighting. If it isn't but it is the window highlight it as inactive
-- the "trick" here is that "bufwinnr" retunrs a value which is the first window associated with a buffer
-- if there are no windows associated i.e. it is not in view and the function returns -1
function Buffer:current()
  return vim.fn.winbufnr(0) == self.id
end

function Buffer:visible()
  return vim.fn.bufwinnr(self.id) > 0
end
