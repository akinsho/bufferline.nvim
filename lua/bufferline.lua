local ui = require("bufferline.ui")
local utils = require("bufferline.utils")
local groups = require("bufferline.groups")
local config = require("bufferline.config")
local sorters = require("bufferline.sorters")
local buffers = require("bufferline.buffers")
local tabpages = require("bufferline.tabpages")
local constants = require("bufferline.constants")
local highlights = require("bufferline.highlights")

local api = vim.api
local fn = vim.fn
local fmt = string.format

local positions_key = constants.positions_key

local M = {}

--- Global namespace for callbacks and other use cases such as commandline completion functions
_G.__bufferline = __bufferline or {}

-----------------------------------------------------------------------------//
-- State
-----------------------------------------------------------------------------//
---@class BufferlineState
---@field components Component[]
---@field visible_components Component[]
---@field __components Component[]
---@field __visible_components Component[]
---@field custom_sort number[]
local state = {
  is_picking = false,
  custom_sort = nil,
  __components = {},
  __visible_components = {},
  components = {},
  visible_components = {},
}
-----------------------------------------------------------------------------//
-- Helpers
-----------------------------------------------------------------------------//

local function refresh()
  vim.cmd("redrawtabline")
  vim.cmd("redraw")
end

---@param bufs number[]
local function save_positions(bufs)
  local positions = table.concat(bufs, ",")
  vim.g[positions_key] = positions
end

function M.restore_positions()
  local str = vim.g[positions_key]
  if not str then
    return str
  end
  local buf_ids = vim.split(str, ",")
  if buf_ids and #buf_ids > 0 then
    -- these are converted to strings when stored
    -- so have to be converted back before usage
    state.custom_sort = vim.tbl_map(tonumber, buf_ids)
  end
end

---------------------------------------------------------------------------//
-- User commands
---------------------------------------------------------------------------//

---Handle a user "command" which can be a string or a function
---@param command string|function
---@param buf_id string
local function handle_user_command(command, buf_id)
  if not command then
    return
  end
  if type(command) == "function" then
    command(buf_id)
  elseif type(command) == "string" then
    vim.cmd(fmt(command, buf_id))
  end
end

---@param group_id number
function M.handle_group_click(group_id)
  groups.toggle_hidden(group_id)
  refresh()
end

---@param buf_id number
function M.handle_close_buffer(buf_id)
  local options = config.get("options")
  local close = options.close_command
  handle_user_command(close, buf_id)
end

---@param id number
function M.handle_win_click(id)
  local win_id = vim.fn.bufwinid(id)
  vim.fn.win_gotoid(win_id)
end

---Handler for each type of mouse click
---@param id number
---@param button string
function M.handle_click(id, button)
  local options = config.get("options")
  local cmds = {
    r = "right_mouse_command",
    l = "left_mouse_command",
    m = "middle_mouse_command",
  }
  if id then
    handle_user_command(options[cmds[button]], id)
  end
end

---Execute an arbitrary user function on a visible by it's position buffer
---@param index number
---@param func fun(num: number)
function M.buf_exec(index, func)
  local target = state.visible_components[index]
  if target and type(func) == "function" then
    func(target, state.visible_components)
  end
end

-- Prompts user to select a buffer then applies a function to the buffer
---@param func fun(buf_id: number)
local function select_buffer_apply(func)
  state.is_picking = true
  refresh()

  local char = vim.fn.getchar()
  local letter = vim.fn.nr2char(char)
  for _, item in ipairs(state.components) do
    local buf = item:as_buffer()
    if buf and letter == buf.letter then
      func(buf.id)
    end
  end

  state.is_picking = false
  refresh()
end

function M.pick_buffer()
  select_buffer_apply(function(buf_id)
    vim.cmd("buffer " .. buf_id)
  end)
end

function M.close_buffer_with_pick()
  select_buffer_apply(function(buf_id)
    M.handle_close_buffer(buf_id)
  end)
end

--- Open a buffer based on it's visible position in the list
--- unless absolute is specified in which case this will open it based on it place in the full list
--- this is significantly less helpful if you have a lot of buffers open
---@param num number | string
---@param absolute boolean whether or not to use the buffers absolute position or visible positions
function M.go_to_buffer(num, absolute)
  num = type(num) == "string" and tonumber(num) or num
  local list = absolute and state.components or state.visible_components
  local buf = list[num]
  if buf then
    vim.cmd(fmt("buffer %d", buf.id))
  end
end

---@param opts table
---@return number
---@return Buffer
local function get_current_buf_index(opts)
  opts = opts or { include_hidden = false }
  local list = opts.include_hidden and state.__components or state.components
  local current = api.nvim_get_current_buf()
  for index, item in ipairs(list) do
    local buf = item:as_buffer()
    if buf and buf.id == current then
      return index, buf
    end
  end
end

--- @param bufs Buffer[]
--- @return number[]
local function get_buf_ids(bufs)
  return vim.tbl_map(function(buf)
    return buf.id
  end, bufs)
end

--- @param direction number
function M.move(direction)
  local index = get_current_buf_index()
  if not index then
    return utils.echoerr("Unable to find buffer to move, sorry")
  end
  local next_index = index + direction
  if next_index >= 1 and next_index <= #state.components then
    local cur_buf = state.components[index]
    local destination_buf = state.components[next_index]
    state.components[next_index] = cur_buf
    state.components[index] = destination_buf
    state.custom_sort = get_buf_ids(state.components)
    local opts = config.get("options")
    if opts.persist_buffer_sort then
      save_positions(state.custom_sort)
    end
    refresh()
  end
end

function M.cycle(direction)
  local index = get_current_buf_index()
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
  local next = item:as_buffer()

  if not next then
    return utils.echoerr("This buffer does not exist")
  end

  vim.cmd("buffer " .. next.id)
end

---@alias direction "'left'" | "'right'"
---Close all buffers to the left or right of the current buffer
---@param direction direction
function M.close_in_direction(direction)
  local index = get_current_buf_index()
  if not index then
    return
  end
  local length = #state.components
  if
    not (index == length and direction == "right") and not (index == 1 and direction == "left")
  then
    local start = direction == "left" and 1 or index + 1
    local _end = direction == "left" and index - 1 or length
    ---@type Buffer[]
    local bufs = vim.list_slice(state.components, start, _end)
    for _, buf in ipairs(bufs) do
      api.nvim_buf_delete(buf.id, { force = true })
    end
  end
end

--- sorts all buffers
--- @param sort_by string|function
function M.sort_buffers_by(sort_by)
  if next(state.components) == nil then
    return utils.echoerr("Unable to find buffers to sort, sorry")
  end

  sorters.sort_buffers(sort_by, state.components)
  state.custom_sort = get_buf_ids(state.components)
  local opts = config.get("options")
  if opts.persist_buffer_sort then
    save_positions(state.custom_sort)
  end
  refresh()
end

---@param list Component[]
---@return Component[]
local function filter_invisible(list)
  return utils.fold({}, function(accum, item)
    if item.focusable ~= false and not item.hidden then
      table.insert(accum, item)
    end
    return accum
  end, list)
end

---sort a list of components using a sort function
---@param list Component[]
---@return Component[]
local function sorter(list)
  -- if the user has reshuffled the buffers manually don't try and sort them
  if state.custom_sort then
    return list
  end
  local options = require("bufferline.config").get("options")
  require("bufferline.sorters").sort_buffers(options.sort_by, list)
  return list
end

--- @return string
local function bufferline()
  local tabs = tabpages.get()
  local components = config.get():is_tabline() and tabpages.get_components(state)
    or buffers.get_components()
  local tabline, visible_components = ui.render(components, tabs)
  --- store the full unfiltered lists
  state.__components = components
  state.__visible_components = visible_components

  --- Store copies without focusable/hidden elements
  state.components = filter_invisible(components)
  state.visible_components = filter_invisible(visible_components)
  return tabline
end

function M.toggle_bufferline()
  local opts = config.get("options")
  local status = (opts.always_show_bufferline or #fn.getbufinfo({ buflisted = 1 }) > 1) and 2 or 0
  vim.o.showtabline = status
end

---@private
function M.__apply_colors()
  local current_prefs = config.update_highlights()
  highlights.set_all(current_prefs.highlights)
end

---@param conf BufferlineConfig
local function setup_autocommands(conf)
  local options = conf.options
  local autocommands = {
    { "ColorScheme", "*", [[lua require('bufferline').__apply_colors()]] },
  }
  if not options or vim.tbl_isempty(options) then
    return
  end
  if options.persist_buffer_sort then
    table.insert(autocommands, {
      "SessionLoadPost",
      "*",
      [[lua require'bufferline'.restore_positions()]],
    })
  end
  if not options.always_show_bufferline then
    -- toggle tabline
    table.insert(autocommands, {
      "BufAdd,TabEnter",
      "*",
      "lua require'bufferline'.toggle_bufferline()",
    })
  end

  if conf:enabled("groups") then
    table.insert(autocommands, {
      "BufReadPre",
      "*",
      "++once",
      "lua vim.schedule(require'bufferline'.handle_group_enter)",
    })
    table.insert(autocommands, {
      "BufEnter",
      "*",
      "lua require'bufferline'.handle_group_enter()",
    })
  end

  utils.augroup({ BufferlineColors = autocommands })
end

---@alias group_actions '"close"' | '"toggle"'
---Execute an action on a group of buffers
---@param name string
---@param action group_actions | fun(b: Buffer)
function M.group_action(name, action)
  assert(name, "A name must be passed to execute a group action")
  if action == "close" then
    groups.command(name, function(b)
      api.nvim_buf_delete(b.id, { force = true })
    end)
  elseif action == "toggle" then
    groups.toggle_hidden(nil, name)
    refresh()
  elseif type(action) == "function" then
    groups.command(name, action)
  end
end

function M.handle_group_enter()
  local options = config.get("options")
  local _, buf = get_current_buf_index({ include_hidden = true })
  if not buf then
    return
  end
  local current_group = groups.get_by_id(buf.group)
  if options.groups.options.toggle_hidden_on_enter then
    if current_group.hidden then
      groups.set_hidden(current_group.id, false)
    end
  end
  utils.for_each(state.components, function(tab)
    local group = groups.get_by_id(tab.group)
    if group and group.auto_close and group.id ~= current_group.id then
      groups.set_hidden(group.id, true)
    end
  end)
end

---@param arg_lead string
---@param cmd_line string
---@param cursor_pos number
---@return string[]
---@diagnostic disable-next-line: unused-local
function __bufferline.complete_groups(arg_lead, cmd_line, cursor_pos)
  return groups.names()
end

local function setup_commands()
  local cmds = {
    { name = "BufferLinePick", cmd = "pick_buffer()" },
    { name = "BufferLinePickClose", cmd = "close_buffer_with_pick()" },
    { name = "BufferLineCycleNext", cmd = "cycle(1)" },
    { name = "BufferLineCyclePrev", cmd = "cycle(-1)" },
    { name = "BufferLineCloseRight", cmd = 'close_in_direction("right")' },
    { name = "BufferLineCloseLeft", cmd = 'close_in_direction("left")' },
    { name = "BufferLineMoveNext", cmd = "move(1)" },
    { name = "BufferLineMovePrev", cmd = "move(-1)" },
    { name = "BufferLineSortByExtension", cmd = 'sort_buffers_by("extension")' },
    { name = "BufferLineSortByDirectory", cmd = 'sort_buffers_by("directory")' },
    { name = "BufferLineSortByRelativeDirectory", cmd = 'sort_buffers_by("relative_directory")' },
    { name = "BufferLineSortByTabs", cmd = 'sort_buffers_by("tabs")' },
    { name = "BufferLineGoToBuffer", cmd = "go_to_buffer(<q-args>)", nargs = 1 },
    {
      nargs = 1,
      name = "BufferLineGroupClose",
      cmd = 'group_action(<q-args>, "close")',
      complete = "complete_groups",
    },
    {
      nargs = 1,
      name = "BufferLineGroupToggle",
      cmd = 'group_action(<q-args>, "toggle")',
      complete = "complete_groups",
    },
  }
  for _, cmd in ipairs(cmds) do
    local nargs = cmd.nargs and fmt("-nargs=%d", cmd.nargs) or ""
    local complete = cmd.complete
        and fmt("-complete=customlist,v:lua.__bufferline.%s", cmd.complete)
      or ""
    vim.cmd(
      fmt('command! %s %s %s lua require("bufferline").%s', nargs, complete, cmd.name, cmd.cmd)
    )
  end
end

---@private
function _G.nvim_bufferline()
  return bufferline()
end

---@private
function M.__load()
  local preferences = config.apply()
  -- on loading (and reloading) the plugin's config reset all the highlights
  highlights.set_all(preferences.highlights)
  -- TODO: don't reapply commands and autocommands if load has already been called
  setup_commands()
  setup_autocommands(preferences)
  vim.o.tabline = "%!v:lua.nvim_bufferline()"
  M.toggle_bufferline()
end

---@param conf BufferlineConfig
function M.setup(conf)
  conf = conf or {}
  config.set(conf)
  if vim.v.vim_did_enter == 1 then
    M.__load()
  else
    -- defer the first load of the plugin till vim has started
    require("bufferline.utils").augroup({
      BufferlineLoad = { { "VimEnter", "*", "++once", "lua require('bufferline').__load()" } },
    })
  end
end

if utils.is_test() then
  M._state = state
  M._get_current_buf_index = get_current_buf_index
end

return M
