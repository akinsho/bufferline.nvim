local fn = vim.fn
--------------------------------
-- Export
--------------------------------
local M = {}

--------------------------------
-- A single buffer
--------------------------------
---@alias BufferComponent fun(index: number, buf_count: number): string

---@class Buffer
---@field public extension string the file extension
---@field public path string the full path to the file
---@field public name_formatter function? dictates how the name should be shown
---@field public id integer the buffer number
---@field public filename string the visible name for the file
---@field public icon string the icon
---@field public icon_highlight string
---@field public diagnostics table
---@field public modified boolean
---@field public modifiable boolean
---@field public buftype string
---@field public letter string
---@field public ordinal number
---@field public duplicated boolean
---@field public prefix_count boolean
---@field public component BufferComponent
local Buffer = {}
---@field public group Group
---@field public group_fn string
local Buffer = {}

---create a new buffer class
---@param buf Buffer
---@return Buffer
function Buffer:new(buf)
  buf.modifiable = vim.bo[buf.id].modifiable
  buf.modified = vim.bo[buf.id].modified
  buf.buftype = vim.bo[buf.id].buftype

  buf.extension = fn.fnamemodify(buf.path, ":e")
  local utils = require("bufferline.utils")
  buf.icon, buf.icon_highlight = utils.get_icon(buf)

  local name = "[No Name]"
  if buf.path and #buf.path > 0 then
    name = fn.fnamemodify(buf.path, ":p:t")
    if buf.name_formatter and type(buf.name_formatter) == "function" then
      name = buf.name_formatter({ name = name, path = buf.path, bufnr = buf.id }) or name
    end
  end
  buf.filename = name

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
function Buffer:current()
  return fn.winbufnr(0) == self.id
end

function Buffer:visible()
  return fn.bufwinnr(self.id) > 0
end

--- @param depth number
--- @param formatter function(string, number)
--- @returns string
function Buffer:ancestor(depth, formatter)
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

    ancestor = dir .. require("bufferline.utils").path_sep .. ancestor
  end
  return ancestor
end

--------------------------------
-- A collection of buffers
--------------------------------

---@class Buffers
---@field buffers Buffers[]
---@field length number
local Buffers = {}

---create a segment of buffers
---@param n Buffers
---@return Buffers
function Buffers:new(n)
  local t = n or { length = 0, buffers = {} }
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

M.Buffer = Buffer
M.Buffers = Buffers

return M
