local lazy = require("bufferline.lazy")
--- @module "bufferline.ui"
local ui = lazy.require("bufferline.ui")
--- @module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
--- @module "bufferline.state"
local state = lazy.require("bufferline.state")
--- @module "bufferline.groups"
local groups = lazy.require("bufferline.groups")
--- @module "bufferline.config"
local config = lazy.require("bufferline.config")
--- @module "bufferline.sorters"
local sorters = lazy.require("bufferline.sorters")
--- @module "bufferline.buffers"
local buffers = lazy.require("bufferline.buffers")
--- @module "bufferline.commands"
local commands = lazy.require("bufferline.commands")
--- @module "bufferline.tabpages"
local tabpages = lazy.require("bufferline.tabpages")
--- @module "bufferline.constants"
local constants = lazy.require("bufferline.constants")
--- @module "bufferline.highlights"
local highlights = lazy.require("bufferline.highlights")

local api = vim.api
local fmt = string.format

local positions_key = constants.positions_key

local M = {
  move = commands.move,
  go_to = commands.go_to,
  cycle = commands.cycle,
  sort_by = commands.sort_by,
  pick_buffer = commands.pick,
  handle_close = commands.handle_close,
  handle_click = commands.handle_click,
  close_with_pick = commands.close_with_pick,
  close_in_direction = commands.close_in_direction,
  handle_group_click = commands.handle_group_click,
  -- @deprecate
  go_to_buffer = commands.go_to,
  sort_buffers_by = commands.sort_by,
  close_buffer_with_pick = commands.close_with_pick,
}

--- Global namespace for callbacks and other use cases such as commandline completion functions
_G.__bufferline = __bufferline or {}
-----------------------------------------------------------------------------//
-- Helpers
-----------------------------------------------------------------------------//
function M.restore_positions()
  local str = vim.g[positions_key]
  if not str then
    return str
  end
  -- these are converted to strings when stored
  -- so have to be converted back before usage
  local ids = vim.split(str, ",")
  if ids and #ids > 0 then
    state.custom_sort = vim.tbl_map(tonumber, ids)
  end
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
  return sorters.sort(list, nil, state)
end

---Get the index of the current element
---@param current_state BufferlineState
---@return number
local function get_current_index(current_state)
  for index, component in ipairs(current_state.components) do
    if component:current() then
      return index
    end
  end
end

--- @return string
local function bufferline()
  local conf = config.get()
  local tabs = tabpages.get()
  local is_tabline = conf:is_tabline()
  local components = is_tabline and tabpages.get_components(state) or buffers.get_components(state)

  --- NOTE: this cannot be added to state as a metamethod since
  --- state is not actually set till after sorting and component creation is done
  state.set({ current_element_index = get_current_index(state) })
  components = not is_tabline and groups.render(components, sorter) or sorter(components)
  local tabline, visible_components = ui.render(components, tabs)

  state.set({
    --- store the full unfiltered lists
    __components = components,
    --- Store copies without focusable/hidden elements
    components = filter_invisible(components),
    visible_components = filter_invisible(visible_components),
  })
  return tabline
end

--- If the item count has changed and the next tabline status is different then update it
function M.toggle_bufferline()
  local item_count = config:is_tabline() and utils.get_tab_count() or utils.get_buf_count()
  local status = (config.options.always_show_bufferline or item_count > 1) and 2 or 0
  if vim.o.showtabline ~= status then
    vim.o.showtabline = status
  end
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

  table.insert(autocommands, {
    "BufRead",
    "*",
    "++once",
    "lua vim.schedule(require'bufferline'.handle_group_enter)",
  })
  table.insert(autocommands, {
    "BufEnter",
    "*",
    "lua require'bufferline'.handle_group_enter()",
  })

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
    ui.refresh()
  elseif type(action) == "function" then
    groups.command(name, action)
  end
end

function M.toggle_pin()
  local _, buffer = commands.get_current_element_index(state)
  if groups.is_pinned(buffer) then
    groups.remove_from_group("pinned", buffer)
  else
    groups.add_to_group("pinned", buffer)
  end
  ui.refresh()
end

function M.handle_group_enter()
  local options = config.options
  local _, element = commands.get_current_element_index(state, { include_hidden = true })
  if not element or not element.group then
    return
  end
  local current_group = groups.get_by_id(element.group)
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
    {
      nargs = 0,
      name = "BufferLineTogglePin",
      cmd = "toggle_pin()",
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
  -- Always populate state regardless of if tabline status is less than 2 #352
  M.toggle_bufferline()
  return bufferline()
end

---@param conf BufferlineConfig
function M.setup(conf)
  conf = conf or {}
  config.set(conf)
  local preferences = config.apply()
  -- on loading (and reloading) the plugin's config reset all the highlights
  highlights.set_all(preferences.highlights)
  setup_commands()
  setup_autocommands(preferences)
  vim.o.tabline = "%!v:lua.nvim_bufferline()"
  M.toggle_bufferline()
end

return M
