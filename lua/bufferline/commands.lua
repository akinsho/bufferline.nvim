---------------------------------------------------------------------------//
-- User commands
---------------------------------------------------------------------------//
local lazy = require("bufferline.lazy")
---@module "bufferline.ui"
local ui = lazy.require("bufferline.ui")
---@module "bufferline.state"
local state = lazy.require("bufferline.state")
---@module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
---@module "bufferline.config"
local config = lazy.require("bufferline.config")
---@module "bufferline.groups"
local groups = lazy.require("bufferline.groups")
---@module "bufferline.sorters"
local sorters = lazy.require("bufferline.sorters")
---@module "bufferline.constants"
local constants = lazy.require("bufferline.constants")

local M = {}

local positions_key = constants.positions_key

local fmt = string.format
local api = vim.api

---@param ids number[]
local function save_positions(ids)
  local positions = table.concat(ids, ",")
  vim.g[positions_key] = positions
end

--- @param elements TabElement[]
--- @return number[]
local function get_ids(elements)
  return vim.tbl_map(function(item)
    return item.id
  end, elements)
end

--- open the current element
---@param id number
local function open_element(id)
  if config:is_tabline() and api.nvim_tabpage_is_valid(id) then
    api.nvim_set_current_tabpage(id)
  elseif api.nvim_buf_is_valid(id) then
    api.nvim_set_current_buf(id)
  end
end

---@param id number
local function delete_element(id)
  if config:is_tabline() then
    vim.cmd("tabclose " .. id)
  else
    api.nvim_buf_delete(id, { force = true })
  end
end

---Get the current element i.e. tab or buffer
---@return number
local function get_current_element()
  if config:is_tabline() then
    return api.nvim_get_current_tabpage()
  end
  return api.nvim_get_current_buf()
end

---Handle a user "command" which can be a string or a function
---@param command string|function
---@param id string
local function handle_user_command(command, id)
  if not command then
    return
  end
  if type(command) == "function" then
    command(id)
  elseif type(command) == "string" then
    vim.cmd(fmt(command, id))
  end
end

---@param position number
function M.handle_group_click(position)
  groups.toggle_hidden(position)
  ui.refresh()
end

---@param id number
function M.handle_close(id)
  local options = config.options
  local close = options.close_command
  handle_user_command(close, id)
end

---@param id number
function M.handle_win_click(id)
  local win_id = vim.fn.bufwinid(id)
  vim.fn.win_gotoid(win_id)
end

local cmds = {
  r = "right_mouse_command",
  l = "left_mouse_command",
  m = "middle_mouse_command",
}
---Handler for each type of mouse click
---@param id number
---@param button string
function M.handle_click(id, button)
  local options = config.options
  if id then
    handle_user_command(options[cmds[button]], id)
  end
end

---Execute an arbitrary user function on a visible by it's position buffer
---@param index number
---@param func fun(num: number)
function M.exec(index, func)
  local target = state.visible_components[index]
  if target and type(func) == "function" then
    func(target, state.visible_components)
  end
end

-- Prompts user to select a buffer then applies a function to the buffer
---@param func fun(id: number)
local function select_element_apply(func)
  state.is_picking = true
  ui.refresh()

  local char = vim.fn.getchar()
  local letter = vim.fn.nr2char(char)
  for _, item in ipairs(state.components) do
    local element = item:as_element()
    if element and letter == element.letter then
      func(element.id)
    end
  end

  state.is_picking = false
  ui.refresh()
end

function M.pick()
  select_element_apply(open_element)
end

function M.close_with_pick()
  select_element_apply(function(id)
    M.handle_close(id)
  end)
end

--- Open a element based on it's visible position in the list
--- unless absolute is specified in which case this will open it based on it place in the full list
--- this is significantly less helpful if you have a lot of elements open
---@param num number | string
---@param absolute boolean whether or not to use the elements absolute position or visible positions
function M.go_to(num, absolute)
  num = type(num) == "string" and tonumber(num) or num
  local list = absolute and state.components or state.visible_components
  local element = list[num]
  if element then
    open_element(element.id)
  end
end

---@param current_state BufferlineState
---@param opts table
---@return number
---@return Buffer
function M.get_current_element_index(current_state, opts)
  opts = opts or { include_hidden = false }
  local list = opts.include_hidden and current_state.__components or current_state.components
  for index, item in ipairs(list) do
    local element = item:as_element()
    if element and element.id == get_current_element() then
      return index, element
    end
  end
end

--- @param direction number
function M.move(direction)
  local index = M.get_current_element_index(state)
  if not index then
    return utils.notify("Unable to find buffer to move, sorry", utils.W)
  end
  local next_index = index + direction
  if next_index >= 1 and next_index <= #state.components then
    local item = state.components[index]
    local destination_buf = state.components[next_index]
    state.components[next_index] = item
    state.components[index] = destination_buf
    state.custom_sort = get_ids(state.components)
    local opts = config.options
    if opts.persist_buffer_sort then
      save_positions(state.custom_sort)
    end
    ui.refresh()
  end
end

function M.cycle(direction)
  local index = M.get_current_element_index(state)
  if not index then
    return
  end
  local length = #state.components
  local next_index = index + direction

  if next_index <= length and next_index >= 1 then
    next_index = index + direction
  elseif index + direction <= 0 then
    next_index = length
  else
    next_index = 1
  end

  local item = state.components[next_index]
  if not item then
    return utils.notify(fmt("This %s does not exist", item.type), utils.E)
  end
  open_element(item.id)
end

---@alias Direction "'left'" | "'right'"
---Close all elements to the left or right of the current buffer
---@param direction Direction
function M.close_in_direction(direction)
  local index = M.get_current_element_index(state)
  if not index then
    return
  end
  local length = #state.components
  if
    not (index == length and direction == "right") and not (index == 1 and direction == "left")
  then
    local start = direction == "left" and 1 or index + 1
    local _end = direction == "left" and index - 1 or length
    for _, item in ipairs(vim.list_slice(state.components, start, _end)) do
      delete_element(item.id)
    end
  end
end

--- sorts all elements
--- @param sort_by string|function
function M.sort_by(sort_by)
  if next(state.components) == nil then
    return utils.notify("Unable to find elements to sort, sorry", utils.W)
  end
  sorters.sort(state.components, sort_by)
  state.custom_sort = get_ids(state.components)
  local opts = config.options
  if opts.persist_buffer_sort then
    save_positions(state.custom_sort)
  end
  ui.refresh()
end

return M
