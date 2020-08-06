local lua_devicons_loaded, webdev_icons = pcall(require, 'nvim-web-devicons')
if lua_devicons_loaded then webdev_icons.setup() end
--------------------------------
-- Export
--------------------------------
local M = {}
--------------------------------
-- Constants
--------------------------------
local terminal_icon = " "
local terminal_buftype = "terminal"

--------------------------------
-- A collection of buffers
--------------------------------
---@class Buffers @parent class
M.Buffers = {}

function M.Buffers:new(n)
  local t = n or {length = 0, buffers = {}}
  self.__index = self
  return setmetatable(t, self)
end

function M.Buffers.__add(a, b)
  return a.length + b.length
end

-- Take a section and remove a buffer arbitrarily
-- reducing the length is very important as otherwise we don't know
-- a section is actually smaller now
function M.Buffers:drop(index)
  if self.buffers[index] ~= nil then
    self.length = self.length - self.buffers[index].length
    table.remove(self.buffers, index)
    return self
  end
end

function M.Buffers:add(buf)
  table.insert(self.buffers, buf)
  self.length = self.length + buf.length
end

local function buffer_is_terminal(buf)
  return string.find(buf.path, 'term://') or buf.buftype == terminal_buftype
end

--------------------------------
-- A single buffer
--------------------------------
---@class Buffer @parent class
M.Buffer = {}

function M.Buffer:new(buf)
  buf.modifiable = vim.fn.getbufvar(buf.id, '&modifiable') == 1
  buf.modified = vim.fn.getbufvar(buf.id, '&modified') == 1
  buf.buftype = vim.fn.getbufvar(buf.id, '&buftype')
  if buf.path == "" then buf.path = "[No Name]" end

  buf.extension = vim.fn.fnamemodify(buf.path, ":e")
  -- Set icon
  if buffer_is_terminal(buf) then
    buf.icon = terminal_icon
    buf.filename = vim.fn.fnamemodify(buf.path, ":p:t")
  else
    if lua_devicons_loaded then
      buf.icon, buf.icon_highlight = webdev_icons.get_icon(buf.path, buf.extension, {
          default = true,
        }
      )
    else
      local devicons_loaded = vim.fn.exists('*WebDevIconsGetFileTypeSymbol') > 0
      buf.icon = devicons_loaded and vim.fn.WebDevIconsGetFileTypeSymbol(buf.path) or ""
    end
    -- TODO: allow the format specifier to be configured
    buf.filename = vim.fn.fnamemodify(buf.path, ":p:t")
  end

  self.__index = self
  return setmetatable(buf, self)
end

-- Borrowed this trick from
-- https://github.com/bagrat/vim-buffet/blob/28e8535766f1a48e6006dc70178985de2b8c026d/autoload/buffet.vim#L186
-- If the current buffer in the current window has a matching ID it is ours and so should
-- have the main selected highlighting. If it isn't but it is the window highlight it as inactive
-- the "trick" here is that "bufwinnr" retunrs a value which is the first window associated with a buffer
-- if there are no windows associated i.e. it is not in view and the function returns -1

-- FIXME this does not work if the same buffer is open in multiple window
-- maybe do something with win_findbuf(bufnr('%'))
function M.Buffer:current()
  return vim.fn.winbufnr(0) == self.id
end

function M.Buffer:visible()
  return vim.fn.bufwinnr(self.id) > 0
end

M.lua_devicons_loaded = lua_devicons_loaded

return M
