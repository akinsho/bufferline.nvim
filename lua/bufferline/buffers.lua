local lua_devicons_loaded, webdev_icons = pcall(require, "nvim-web-devicons")
local utils = require("bufferline/utils")
local fn = vim.fn
--------------------------------
-- Export
--------------------------------
local M = {}
--------------------------------
-- Constants
--------------------------------
local terminal_icon = " "
local terminal_buftype = "terminal"

-----------------------------------------------------------------------------//
-- helpers
-----------------------------------------------------------------------------//
local function buffer_is_terminal(buf)
  return string.find(buf.path, "term://") or buf.buftype == terminal_buftype
end
--------------------------------
-- A single buffer
--------------------------------
---@class Buffer
---@field public extension string,
---@field public path string,
---@field public id integer,
---@field public filename string,
---@field public icon string,
---@field public icon_highlight string,
---@field public diagnostics table
---@field public modified boolean
---@field public modifiable boolean
---@field public buftype string
---@field public letter string
M.Buffer = {}

---create a new buffer class
---@param buf Buffer
---@return Buffer
function M.Buffer:new(buf)
  buf.modifiable = vim.bo[buf.id].modifiable
  buf.modified = vim.bo[buf.id].modified
  buf.buftype = vim.bo[buf.id].buftype

  buf.extension = fn.fnamemodify(buf.path, ":e")
  -- Set icon
  if buffer_is_terminal(buf) then
    if lua_devicons_loaded then
      terminal_icon = webdev_icons.get_icon("terminal") .. " "
    end
    buf.icon = terminal_icon
    buf.filename = fn.fnamemodify(buf.path, ":p:t")
  else
    if lua_devicons_loaded then
      buf.icon, buf.icon_highlight = webdev_icons.get_icon(
        fn.fnamemodify(buf.path, ":t"),
        buf.extension,
        { default = true }
      )
    else
      local devicons_loaded = fn.exists("*WebDevIconsGetFileTypeSymbol") > 0
      buf.icon = devicons_loaded and fn.WebDevIconsGetFileTypeSymbol(buf.path) or ""
    end
    -- TODO: allow the format specifier to be configured
    buf.filename = (buf.path and #buf.path > 0) and fn.fnamemodify(buf.path, ":p:t") or "[No Name]"
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
  return fn.winbufnr(0) == self.id
end

function M.Buffer:visible()
  return fn.bufwinnr(self.id) > 0
end

--- @param depth number
--- @param formatter function(string, number)
--- @returns string
function M.Buffer:ancestor(depth, formatter)
  depth = (depth and depth > 1) and depth or 1
  local ancestor = ""
  for index = 1, depth do
    local modifier = string.rep(":h", index)
    local dir = fn.fnamemodify(self.path, ":p" .. modifier .. ":t")
    if dir == "" then
      break
    end
    if formatter then
      dir = formatter(dir, depth)
    end
    ancestor = dir .. utils.path_sep .. ancestor
  end
  return ancestor
end

--------------------------------
-- A collection of buffers
--------------------------------

---@class Buffers
---@field buffers Buffers[]
M.Buffers = {}

---create a segment of buffers
---@param n Buffers
---@return Buffers
function M.Buffers:new(n)
  local t = n or { length = 0, buffers = {} }
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

return M
