local ui = require("bufferline.ui")
local utils = require("bufferline.utils")
local state = require("bufferline.state")
local groups = require("bufferline.groups")
local config = require("bufferline.config")
local sorters = require("bufferline.sorters")
local buffers = require("bufferline.buffers")
local commands = require("bufferline.commands")
local tabpages = require("bufferline.tabpages")
local constants = require("bufferline.constants")
local highlights = require("bufferline.highlights")

local api = vim.api
local fn = vim.fn
local fmt = string.format

local positions_key = constants.positions_key

local M = {
  move = commands.move,
  go_to = commands.go_to,
  cycle = commands.cycle,
  sort_by = commands.sort_by,
  pick_buffer = commands.pick,
  close_with_pick = commands.close_with_pick,
  close_in_direction = commands.close_in_direction,
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
  return sorters.sort(list)
end

--- @return string
local function bufferline()
  local conf = config.get()
  local tabs = tabpages.get()
  local is_tabline = conf:is_tabline()
  local has_groups = config:enabled("groups")
  local components = is_tabline and tabpages.get_components(state) or buffers.get_components(state)

  components = has_groups and not is_tabline and groups.render(components, sorter)
    or sorter(components)

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
  local opts = config.options
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
    ui.refresh()
  elseif type(action) == "function" then
    groups.command(name, action)
  end
end

function M.handle_group_enter()
  local options = config.options
  local _, element = commands.get_current_element_index({ include_hidden = true })
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
  M._get_current_buf_index = M.get_current_buf_index
end

return M
