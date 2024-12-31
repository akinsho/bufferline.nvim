local lazy = require("bufferline.lazy")
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local log = lazy.require("bufferline.utils.log") ---@module "bufferline.utils.log"
local constants = lazy.require("bufferline.constants") ---@module "bufferline.constants"

local M = {}

local api = vim.api
local fn = vim.fn
local fmt = string.format
local visibility = constants.visibility

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
---@class bufferline.Component
local Component = {}

---@param field string
local function not_implemented(field)
  log.debug(debug.traceback("Stack trace:"))
  error(fmt("%s is not implemented yet", field))
end

---@generic T
---@param t table
---@return T
function Component:new(t)
  assert(t.type, "all components must have a type")
  self.length = t.length or 0
  self.focusable = true
  if t.focusable ~= nil then self.focusable = t.focusable end
  self.component = t.component or function() not_implemented("component") end
  setmetatable(t, self)
  self.__index = self
  return t
end

-- TODO: this should be handled based on the type of entity
-- e.g. a buffer should report if it's current but other things shouldn't
function Component:current() not_implemented("current") end

---Determine if the current view tab should be treated as the end of a section
---@return boolean
function Component:is_end() return self.type:match("group") end

---@return bufferline.TabElement?
function Component:as_element()
  -- TODO: Figure out how to correctly type cast a component to a TabElement
  ---@diagnostic disable-next-line: return-type-mismatch
  if vim.tbl_contains({ "buffer", "tab" }, self.type) then return self end
end

---Find the directory prefix of an element up to a certain depth
---@param depth integer
---@param formatter (fun(path: string, depth: integer): string)?
---@return string
function Component:__ancestor(depth, formatter)
  if self.type ~= "buffer" and self.type ~= "tab" then return "" end
  local parts = vim.split(self.path, utils.path_sep, { trimempty = true })
  local index = (depth and depth > #parts) and 1 or (#parts - depth) + 1
  local dir = table.concat(parts, utils.path_sep, index, #parts - 1) .. utils.path_sep
  if dir == "" then return "" end
  if formatter then dir = formatter(dir, depth) end
  return dir
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

function GroupView:current() return false end

---@type bufferline.Tab
local Tabpage = Component:new({ type = "tab" })

local function get_modified_state(buffers)
  for _, buf in pairs(buffers) do
    if vim.bo[buf].modified then return true end
  end
  return false
end

function Tabpage:new(tab)
  tab.name = fn.fnamemodify(tab.path, ":t")
  assert(tab.buf, fmt("A tab must a have a buffer: %s", vim.inspect(tab)))
  tab.modifiable = vim.bo[tab.buf].modifiable
  tab.modified = get_modified_state(tab.buffers)
  tab.buftype = vim.bo[tab.buf].buftype
  tab.extension = fn.fnamemodify(tab.path, ":e")
  ---@type bufferline.TabFormatterOpts
  local formatter_opts = {
    name = tab.name,
    path = tab.path,
    bufnr = tab.buf,
    tabnr = tab.id,
    buffers = tab.buffers,
  }
  if tab.name_formatter and type(tab.name_formatter) == "function" then
    tab.name = tab.name_formatter(formatter_opts) or tab.name
  end
  tab.icon, tab.icon_highlight = utils.get_icon(vim.tbl_extend("keep", {
    filetype = vim.bo[tab.buf].filetype,
    directory = fn.isdirectory(tab.path) > 0,
    extension = tab.extension,
    type = tab.buftype,
  }, formatter_opts))
  setmetatable(tab, self)
  self.__index = self
  return tab
end

--- @return bufferline.Visibility
function Tabpage:visibility()
  if self:current() then return visibility.SELECTED end
  if self:visible() then return visibility.INACTIVE end
  return visibility.NONE
end

function Tabpage:current() return api.nvim_get_current_tabpage() == self.id end

--- NOTE: A visible tab page is the current tab page
function Tabpage:visible() return api.nvim_get_current_tabpage() == self.id end

--- @param depth number
--- @param formatter fun(string, number)
--- @return string
function Tabpage:ancestor(depth, formatter)
  if self.duplicated == "element" then return "(duplicated) " end
  return self:__ancestor(depth, formatter)
end

---@alias BufferComponent fun(index: integer, buf_count: integer): bufferline.Segment[]

---@type bufferline.Buffer
local Buffer = Component:new({ type = "buffer" })

---create a new buffer class
---@param buf bufferline.Buffer
---@return bufferline.Buffer
function Buffer:new(buf)
  assert(buf, "A buffer must be passed to create a buffer class")
  buf.modifiable = vim.bo[buf.id].modifiable
  buf.modified = vim.bo[buf.id].modified
  buf.buftype = vim.bo[buf.id].buftype
  buf.extension = fn.fnamemodify(buf.path, ":e")
  local is_directory = fn.isdirectory(buf.path) > 0
  local name = "[No Name]"
  if buf.path and #buf.path > 0 then
    name = fn.fnamemodify(buf.path, ":t")
    name = is_directory and name .. "/" or name
  end

  ---@type bufferline.BufFormatterOpts
  local formatter_opts = {
    name = name,
    path = buf.path,
    bufnr = buf.id,
  }
  if buf.name_formatter and type(buf.name_formatter) == "function" then
    name = buf.name_formatter(formatter_opts) or name
  end

  buf.icon, buf.icon_highlight = utils.get_icon(vim.tbl_extend("keep", {
    filetype = vim.bo[buf.id].filetype,
    directory = is_directory,
    extension = buf.extension,
    type = buf.buftype,
  }, formatter_opts))

  buf.name = name

  setmetatable(buf, self)
  self.__index = self
  return buf
end

---@return bufferline.Visibility
function Buffer:visibility()
  if self:current() then return visibility.SELECTED end
  if self:visible() then return visibility.INACTIVE end
  return visibility.NONE
end

function Buffer:current() return api.nvim_get_current_buf() == self.id end

--- If the buffer is already part of state then it is existing
--- otherwise it is new
---@param components bufferline.TabElement[]
---@return boolean
function Buffer:previously_opened(components)
  return utils.find(function(component) return component.id == self.id end, components) ~= nil
end

--- Find and return the index of the matching buffer (by id) in the list in state
---@param components bufferline.TabElement[]
function Buffer:find_index(components)
  for index, component in ipairs(components) do
    if component.id == self.id then return index end
  end
end

---@param components bufferline.TabElement[]
function Buffer:newly_opened(components) return not self:previously_opened(components) end

function Buffer:visible() return fn.bufwinnr(self.id) > 0 end

--- @param depth integer
--- @param formatter fun(string, integer)
--- @return string
function Buffer:ancestor(depth, formatter) return self:__ancestor(depth, formatter) end

---@type bufferline.Section
local Section = {}

---Create a segment of tab views
---@param n bufferline.Section?
---@return bufferline.Section
function Section:new(n)
  local t = n or { length = 0, items = {} }
  setmetatable(t, self)
  self.__index = self
  return t
end

function Section.__add(a, b) return a.length + b.length end

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

---@param item bufferline.Component
function Section:add(item)
  table.insert(self.items, item)
  self.length = self.length + item.length
end

M.Buffer = Buffer
M.Tabpage = Tabpage
M.Section = Section
M.GroupView = GroupView

return M
