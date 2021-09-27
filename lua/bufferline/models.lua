local M = {}

local api = vim.api
local fn = vim.fn
local fmt = string.format

--[[
-----------------------------------------------------------------------------//
-- Models
-----------------------------------------------------------------------------//
This file contains all the different kinds of entities that are shown in the tabline
They are all subtypes of Components which specifies the base interface for all types
i.e.
- A [component] - which is a function that returns the string to be rendered
- A current method - to indicate if the entity is selected (if possible)
- An end_component method - to indicate if the component represents the end of a block
- [length] - the size of the string component minus highlights which don't render
- [type] - a string enum representing the type of an entity

* this list is not exhaustive
--]]

--- The base class that represents a visual tab in the tabline
--- i.e. not necessarily representative of a vim tab or buffer
---@class Component
---@field length number
---@field component function
---@field hidden boolean
---@field focusable boolean
---@field type "'group_end'" | "'group_start'" | "'buffer'"
local Component = {}

---@param field string
local function not_implemented(field)
  require("bufferline.utils").log.debug(debug.traceback("Stack trace:"))
  error(fmt("%s is not implemented yet", field))
end

function Component:new(t)
  assert(t.type, "all components must have a type")
  self.length = t.length or 0
  self.focusable = true
  if t.focusable ~= nil then
    self.focusable = t.focusable
  end
  self.component = t.component or function()
    not_implemented("component")
  end
  setmetatable(t, self)
  self.__index = self
  return t
end

-- TODO: this should be handled based on the type of entity
-- e.g. a buffer should report if it's current but other things shouldn't
function Component:current()
  not_implemented("current")
end

---Determine if the current view tab should be treated as the end of a section
---@return boolean
function Component:is_end()
  return self.type:match("group")
end

---@return Buffer?
function Component:as_buffer()
  if self.type ~= "buffer" then
    require("bufferline.utils").log.debug(
      fmt("This entity is not a buffer, it is a %s.", self.type)
    )
    return
  end
  return self
end

local GroupView = Component:new({ type = "group", focusable = false })

function GroupView:new(group)
  assert(group, "The type should be passed to a group on create")
  assert(group.component, "a group MUST have a component")
  self.type = group.type or self.type
  setmetatable(group, self)
  self.__index = self
  return group
end

function GroupView:current()
  return false
end

---@alias BufferComponent fun(index: number, buf_count: number): string

-- A single buffer class
-- this extends the [Component] class
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
---@field public group Group
---@field public group_fn string
---@field public length number the length of the buffer component
local Buffer = Component:new({ type = "buffer" })

---create a new buffer class
---@param buf Buffer
---@return Buffer
function Buffer:new(buf)
  assert(buf, "A buffer must be passed to create a buffer class")
  buf.modifiable = vim.bo[buf.id].modifiable
  buf.modified = vim.bo[buf.id].modified
  buf.buftype = vim.bo[buf.id].buftype
  buf.extension = fn.fnamemodify(buf.path, ":e")
  local is_directory = fn.isdirectory(buf.path) > 0
  buf.icon, buf.icon_highlight = require("bufferline.utils").get_icon(buf, is_directory)
  local name = "[No Name]"
  if buf.path and #buf.path > 0 then
    name = fn.fnamemodify(buf.path, ":t")
    name = is_directory and name .. "/" or name
    if buf.name_formatter and type(buf.name_formatter) == "function" then
      name = buf.name_formatter({ name = name, path = buf.path, bufnr = buf.id }) or name
    end
  end
  buf.filename = name
  setmetatable(buf, self)
  self.__index = self
  return buf
end

-- Borrowed this trick from
-- https://github.com/bagrat/vim-buffet/blob/28e8535766f1a48e6006dc70178985de2b8c026d/autoload/buffet.vim#L186
-- If the current buffer in the current window has a matching ID it is ours and so should
-- have the main selected highlighting. If it isn't but it is the window highlight it as inactive
-- the "trick" here is that "bufwinnr" returns a value which is the first window associated with a buffer
-- if there are no windows associated i.e. it is not in view and the function returns -1
-- FIXME: this does not work if the same buffer is open in multiple window
-- maybe do something with win_findbuf(bufnr('%'))
function Buffer:current()
  return api.nvim_win_get_buf(api.nvim_get_current_win()) == self.id
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

---@class Section
---@field items Component[]
---@field length number
local Section = {}

---Create a segment of tab views
---@param n Section
---@return Section
function Section:new(n)
  local t = n or { length = 0, items = {} }
  setmetatable(t, self)
  self.__index = self
  return t
end

function Section.__add(a, b)
  return a.length + b.length
end

-- Take a section and remove an item arbitrarily
-- reducing the length is very important as otherwise we don't know
-- a section is actually smaller now
function Section:drop(index)
  if self.items[index] ~= nil then
    self.length = self.length - self.items[index].length
    table.remove(self.items, index)
    return self
  end
end

function Section:add(item)
  table.insert(self.items, item)
  self.length = self.length + item.length
end

M.Buffer = Buffer
M.Section = Section
M.GroupView = GroupView

return M
