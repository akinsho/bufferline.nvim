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
--- @module "bufferline.hover"
local hover = lazy.require("bufferline.hover")

-- @v:lua@ in the tabline only supports global functions, so this is
-- the only way to add click handlers without autoloaded vimscript functions
_G.___bufferline_private = _G.___bufferline_private or {} -- to guard against reloads

local api = vim.api

local positions_key = constants.positions_key
local BUFFERLINE_GROUP = "BufferlineCmds"

local M = {
  move = commands.move,
  exec = commands.exec,
  go_to = commands.go_to,
  cycle = commands.cycle,
  sort_by = commands.sort_by,
  pick_buffer = commands.pick,
  get_elements = commands.get_elements,
  close_with_pick = commands.close_with_pick,
  close_in_direction = commands.close_in_direction,
  -- @deprecate
  go_to_buffer = commands.go_to,
  sort_buffers_by = commands.sort_by,
  close_buffer_with_pick = commands.close_with_pick,
}
-----------------------------------------------------------------------------//
-- Helpers
-----------------------------------------------------------------------------//
local function restore_positions()
  local str = vim.g[positions_key]
  if not str then return str end
  -- these are converted to strings when stored
  -- so have to be converted back before usage
  local ids = vim.split(str, ",")
  if ids and #ids > 0 then state.custom_sort = vim.tbl_map(tonumber, ids) end
end

---@param list Component[]
---@return Component[]
local function filter_invisible(list)
  return utils.fold({}, function(accum, item)
    if item.focusable ~= false and not item.hidden then table.insert(accum, item) end
    return accum
  end, list)
end

---sort a list of components using a sort function
---@param list Component[]
---@return Component[]
local function sorter(list)
  -- if the user has reshuffled the buffers manually don't try and sort them
  if state.custom_sort then return list end
  return sorters.sort(list, nil, state)
end

---Get the index of the current element
---@param current_state BufferlineState
---@return number?
local function get_current_index(current_state)
  for index, component in ipairs(current_state.components) do
    if component:current() then return index end
  end
end

--- @return string, Segment[][]
local function bufferline()
  local conf = config.get()
  if not conf then return "", {} end
  local is_tabline = conf:is_tabline()
  local components = is_tabline and tabpages.get_components(state) or buffers.get_components(state)

  --- NOTE: this cannot be added to state as a metamethod since
  --- state is not actually set till after sorting and component creation is done
  state.set({ current_element_index = get_current_index(state) })
  components = not is_tabline and groups.render(components, sorter) or sorter(components)
  local tabline = ui.tabline(components, tabpages.get())

  state.set({
    --- store the full unfiltered lists
    __components = components,
    --- Store copies without focusable/hidden elements
    components = filter_invisible(components),
    visible_components = filter_invisible(tabline.visible_components),
    --- size data stored for use elsewhere e.g. hover positioning
    left_offset_size = tabline.left_offset_size,
    right_offset_size = tabline.right_offset_size,
  })
  return tabline.str, tabline.segments
end

--- If the item count has changed and the next tabline status is different then update it
local function toggle_bufferline()
  local item_count = config:is_tabline() and utils.get_tab_count() or utils.get_buf_count()
  local status = (config.options.always_show_bufferline or item_count > 1) and 2 or 0
  if vim.o.showtabline ~= status then vim.o.showtabline = status end
end

local function apply_colors()
  highlights.reset_icon_hl_cache()
  highlights.set_all(config.update_highlights())
end

---@alias group_actions "close" | "toggle"
---Execute an action on a group of buffers
---@param name string
---@param action group_actions | fun(b: NvimBuffer)
function M.group_action(name, action)
  assert(name, "A name must be passed to execute a group action")
  if action == "close" then
    groups.command(name, function(b) api.nvim_buf_delete(b.id, { force = true }) end)
  elseif action == "toggle" then
    groups.toggle_hidden(nil, name)
    ui.refresh()
  elseif type(action) == "function" then
    groups.command(name, action)
  end
end

function M.toggle_pin()
  local _, element = commands.get_current_element_index(state)
  if not element then return end
  if groups.is_pinned(element) then
    groups.remove_from_group("pinned", element)
  else
    groups.add_to_group("pinned", element)
  end
  ui.refresh()
end

local function handle_group_enter()
  local options = config.options
  local _, element = commands.get_current_element_index(state, { include_hidden = true })
  if not element or not element.group then return end
  local current_group = groups.get_by_id(element.group)
  if options.groups.options.toggle_hidden_on_enter then
    if current_group.hidden then groups.set_hidden(current_group.id, false) end
  end
  utils.for_each(function(tab)
    local group = groups.get_by_id(tab.group)
    if group and group.auto_close and group.id ~= current_group.id then
      groups.set_hidden(group.id, true)
    end
  end, state.components)
end

---@param conf BufferlineConfig
local function setup_autocommands(conf)
  local options = conf.options
  api.nvim_create_augroup(BUFFERLINE_GROUP, { clear = true })
  api.nvim_create_autocmd("ColorScheme", {
    pattern = "*",
    group = BUFFERLINE_GROUP,
    callback = function() apply_colors() end,
  })
  if not options or vim.tbl_isempty(options) then return end
  if options.persist_buffer_sort then
    api.nvim_create_autocmd("SessionLoadPost", {
      pattern = "*",
      group = BUFFERLINE_GROUP,
      callback = function() restore_positions() end,
    })
  end
  if not options.always_show_bufferline then
    -- toggle tabline
    api.nvim_create_autocmd({ "BufAdd", "TabEnter" }, {
      pattern = "*",
      group = BUFFERLINE_GROUP,
      callback = function() toggle_bufferline() end,
    })
  end

  api.nvim_create_autocmd("BufRead", {
    pattern = "*",
    once = true,
    callback = function() vim.schedule(handle_group_enter) end,
  })

  api.nvim_create_autocmd("BufEnter", {
    pattern = "*",
    callback = function() handle_group_enter() end,
  })

  api.nvim_create_autocmd("User", {
    pattern = "BufferLineHoverOver",
    callback = function(args) ui.on_hover_over(args.buf, args.data) end,
  })

  api.nvim_create_autocmd("User", {
    pattern = "BufferLineHoverOut",
    callback = ui.on_hover_out,
  })
end

---@param arg_lead string
---@param cmd_line string
---@param cursor_pos number
---@return string[]
---@diagnostic disable-next-line: unused-local
local function complete_groups(arg_lead, cmd_line, cursor_pos) return groups.names() end

local function setup_commands()
  local cmd = api.nvim_create_user_command
  cmd("BufferLinePick", function() M.pick_buffer() end, {})
  cmd("BufferLinePickClose", function() M.close_buffer_with_pick() end, {})
  cmd("BufferLineCycleNext", function() M.cycle(1) end, {})
  cmd("BufferLineCyclePrev", function() M.cycle(-1) end, {})
  cmd("BufferLineCloseRight", function() M.close_in_direction("right") end, {})
  cmd("BufferLineCloseLeft", function() M.close_in_direction("left") end, {})
  cmd("BufferLineMoveNext", function() M.move(1) end, {})
  cmd("BufferLineMovePrev", function() M.move(-1) end, {})
  cmd("BufferLineSortByExtension", function() M.sort_buffers_by("extension") end, {})
  cmd("BufferLineSortByDirectory", function() M.sort_buffers_by("directory") end, {})
  cmd(
    "BufferLineSortByRelativeDirectory",
    function() M.sort_buffers_by("relative_directory") end,
    {}
  )
  cmd("BufferLineSortByTabs", function() M.sort_buffers_by("tabs") end, {})
  cmd("BufferLineGoToBuffer", function(opts) M.go_to_buffer(opts.args) end, { nargs = 1 })
  cmd(
    "BufferLineGroupClose",
    function(opts) M.group_action(opts.args, "close") end,
    { nargs = 1, complete = complete_groups }
  )
  cmd(
    "BufferLineGroupToggle",
    function(opts) M.group_action(opts.args, "toggle") end,
    { nargs = 1, complete = complete_groups }
  )
  cmd("BufferLineTogglePin", function() M.toggle_pin() end, { nargs = 0 })
end

---@private
function _G.nvim_bufferline()
  -- Always populate state regardless of if tabline status is less than 2 #352
  toggle_bufferline()
  return bufferline()
end

---@param conf BufferlineConfig?
function M.setup(conf)
  if not utils.is_current_stable_release() then
    utils.notify(
      "bufferline.nvim requires Neovim 0.7 or higher, please use tag 1.* or update your neovim",
      "error",
      { once = true }
    )
    return
  end
  conf = conf or {}
  config.set(conf)
  groups.setup(conf) -- Groups must be set up before the config is applied
  local preferences = config.apply()
  -- on loading (and reloading) the plugin's config reset all the highlights
  highlights.set_all(preferences)
  hover.setup(preferences)
  setup_commands()
  setup_autocommands(preferences)
  vim.o.tabline = "%!v:lua.nvim_bufferline()"
  toggle_bufferline()
end

return M
