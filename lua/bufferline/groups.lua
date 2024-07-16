local lazy = require("bufferline.lazy")
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local models = lazy.require("bufferline.models") ---@module "bufferline.models"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"
local commands = lazy.require("bufferline.commands") ---@module "bufferline.commands"
local state = lazy.require("bufferline.state") ---@module "bufferline.state"
local C = lazy.require("bufferline.constants") ---@module "bufferline.constants"

local fn = vim.fn

-- contains info about the changes
-- local pr = require('bufferline.pr').get_instance()

--- @Group PR
-- 1. Made type on_close optional in bufferline.Group type [types.lua:193]
-- 2. in Group Setup - added group specific separator options - such as placing the sep at start/end [config.lua:678]
-- 3. Added functionality to Add/Remove groups on their own, for flexibility [groups:286]
-- 4. Fixed the render() function and kept the old one for reference [groups:913]
-- 5. Added a BufferLineDebug user command to print the rendered tabline with HL's and Text + Padding [bufferline:207]
-- 6. Updated doc to provide more info on how to use options [doc/bufferline.txt]
-- 7. Added a  set_bufferline_hls function for the user to directly specify all the styles required for Group Labels and Buffers in one go [pr:38]
-- 8. Fixed the error of BufferLineCyclePrev/Next not working when current buffer is toggled and in a group [commands.lua:204 and groups:67]

----------------------------------------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------------------------------------

local PINNED_ID = "pinned"
local PINNED_NAME = "pinned"
local UNGROUPED_NAME = "ungrouped"
local UNGROUPED_ID = "ungrouped"
local PINNED_KEY = "BufferlinePinnedBuffers"

local api = vim.api
local fmt = string.format

local M = {}

----------------------------------------------------------------------------------------------------
-- UTILS
----------------------------------------------------------------------------------------------------

--- Remove illegal characters from a group name name
---@param name string
local function format_name(name) return name:gsub("[^%w]+", "_") end

----------------------------------------------------------------------------------------------------
-- SEPARATORS
----------------------------------------------------------------------------------------------------

-- initialized in setup() by reading config
local group_sep_position = "both" -- "start" , "end" , "both"
local group_sep_left, group_sep_right = "▎", "▎" -- thin/thick/custom

local separator = {}

------------------------------------------------------------
--- @Change : Fixed logic for Group Tabs

function M.set_group_hls(group_name, opts) require("bufferline.pr").set_group_hls(group_name, opts) end

---@param group bufferline.Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return bufferline.Separators
function separator.pill(group, hls, count)
  local bg_hl = hls.fill.hl_group
  local name, display_name = group.name, group.display_name
  local sep_grp, label_grp = hls[fmt("%s_separator", name)], hls[fmt("%s_label", name)]
  local sep_hl = sep_grp and sep_grp.hl_group or hls.group_separator.hl_group
  local label_hl = label_grp and label_grp.hl_group or hls.group_label.hl_group
  local left, right = "█", "█"

  local start_group_sep = group_sep_left
  local end_group_sep = group_sep_right

  if group_sep_position == "start" then
    end_group_sep = ""
  elseif group_sep_position == "end" then
    start_group_sep = ""
  end
  local end_tab_sep = { highlight = sep_hl, text = end_group_sep }

  local indicator = {
    { text = start_group_sep, highlight = bg_hl },
    { text = left, highlight = sep_hl },
    { text = display_name .. count, highlight = label_hl },
    { text = right, highlight = sep_hl },
    { text = C.padding, highlight = bg_hl },
  }

  -- old pill creation
  --    local indicator = {  -- old
  --        { text = C.padding,             highlight = bg_hl },
  --        { text = left,                  highlight = sep_hl },
  --        { text = display_name .. count, highlight = label_hl },
  --        { text = right,                 highlight = sep_hl },
  --        { text = C.padding,             highlight = bg_hl },
  --    }
  -- return { sep_start = indicator, sep_end = space_end(hls) }

  return { sep_start = indicator, sep_end = { end_tab_sep } }
end

--- Util function to get label sep highlight groups
--- @param group bufferline.Group,
--- @param hls  table<string, table<string, string>>
--- @return string
--- @return string
local function get_label_sep_hls(group, hls)
  local name = group.name
  local label_grp = hls[fmt("%s_label", name)]
  local label_hl = label_grp and label_grp.hl_group or hls.group_label.hl_group
  local sep_grp = hls[fmt("%s_separator", name)]
  local sep_hl = sep_grp and sep_grp.hl_group or hls.group_separator.hl_group
  return label_hl, sep_hl
end

--- @param group bufferline.Group,
--- @param count string
--- @return string
local function get_tab_label(group, count)
  local group_name = group.display_name or group.name
  local count_text = count and #count > 0 and " " .. count or ""
  return fmt(" %s%s ", group_name, count_text)
end

--- @param hl string
--- @param text string
--- @return bufferline.Segment
local function create_style(hl, text) return { highlight = hl, text = text } end

--- Creates the tab for the group
---@param group bufferline.Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@param group_sep_pos string
---@param groupsep_left string
---@param groupsep_right string
---@return bufferline.Separators
local function create_tab(group, hls, count, group_sep_pos, groupsep_left, groupsep_right)
  local hl = hls.fill.hl_group
  local label_hl, sep_hl = get_label_sep_hls(group, hls)

  local tab_label_text = get_tab_label(group, count)

  local tab_left, tab_label = create_style(hl, ""), create_style(label_hl, tab_label_text)

  local start_group_sep, end_group_sep = groupsep_left, groupsep_right

  if group_sep_pos == "start" then
    end_group_sep = ""
  elseif group_sep_pos == "end" then
    start_group_sep = ""
  end

  local start_tab_sep, end_tab_sep = create_style(sep_hl, start_group_sep), create_style(sep_hl, end_group_sep)

  local indicator = { tab_left, tab_label, start_tab_sep }

  return { sep_start = indicator, sep_end = { end_tab_sep } }
end

---@param group bufferline.Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return bufferline.Separators
---@type GroupSeparator
function separator.tab(group, hls, count)
  local tab_gen = create_tab(group, hls, count, group_sep_position, group_sep_left, group_sep_right)
  return tab_gen
end

--[[ Old Separator creation -
---@param group bufferline.Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return bufferline.Separators
---@type GroupSeparator
function separator.tab_old(group, hls, count)
    local hl = hls.fill.hl_group
    local indicator_hl = hls.buffer.hl_group
    local indicator = {
        { highlight = hl,           text = C.padding },
        { highlight = indicator_hl, text = C.padding .. group.name .. count .. C.padding },
        { highlight = hl,           text = C.padding },
    }
    return { sep_start = indicator, sep_end = space_end(hls) }
end
--]]

---@type GroupSeparator
function separator.none() return { sep_start = {}, sep_end = {} } end

----------------------------------------------------------------------------------------------------
-- BUILTIN GROUPS
----------------------------------------------------------------------------------------------------
local builtin = {}

--- @type bufferline.Group
local Group = {}

---@param o bufferline.Group
---@param index number?
---@return bufferline.Group
function Group:new(o, index)
  ---------
  o = o or { priority = index }
  self.__index = self
  local name = format_name(o.name)
  o = vim.tbl_extend("force", o, {
    id = o.id or name,
    hidden = o.hidden == nil and false or o.hidden,
    name = name,
    -- display_name = o.name, priority to display name here
    display_name = o.display_name or o.name,
    priority = o.priority or index, -- ungrouped has no priority set , pinned has it by default
  })
  return setmetatable(o, self)
end

function Group:with(o)
  for key, value in pairs(o) do
    self[key] = value
  end
  return self
end

builtin.ungrouped = Group:new({
  id = UNGROUPED_ID,
  name = UNGROUPED_NAME,
  separator = {
    style = separator.none,
  },
})

builtin.pinned = Group:new({
  id = PINNED_ID,
  name = PINNED_NAME,
  icon = "📌",
  priority = 1,
  separator = {
    style = separator.none,
  },
})

----------------------------------------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------------------------------------

-- user_groups = Map[group_id | group_name, group]

--- @type bufferline.GroupState
local group_state = {
  -- A table of buffers mapped to a specific group by a user
  manual_groupings = {},
  user_groups = {},
  --- Represents a list of maps of type `{id = buf_id, index = position in list}`
  --- so that rather than storing the components we store their positions
  --- with an easy way to look them up later.
  --- e.g. `[[group 1, {id = 12, index = 1}, {id = 10, index 2}], [group 2, {id = 5, index = 3}]]`
  components_by_group = {},
}

-- Maintain count of toggled groups - to fix cycling not working if the user toggles an active tab
local toggled_groups = 0

--- This solves the issue of cycling when the user is on a toggled group
--- We keep a count of how many groups are currently toggled off (minimized)
--- thus we can get the next index by passing the count of toggled groups as the index (1 for example)
function M.toggled_index()
  if toggled_groups >= 1 then return toggled_groups end
end

--- @param count 1 | -1
local function update_toggled(count)
  assert(count == 1 or count == -1, "count must be either 1 or -1")
  assert(toggled_groups + count <= vim.tbl_count(group_state.user_groups), "count cannot exceed number of user groups")
  assert(toggled_groups + count >= 0, "count cannot be lower than 0 " .. toggled_groups)
  toggled_groups = toggled_groups + count
end

--- Store a list of pinned buffer as a string of ids e.g. "12,10,5"
--- in a vim.g global variable that can be persisted across vim sessions
local function persist_pinned_buffers()
  local pinned = {}
  for buf, group in pairs(group_state.manual_groupings) do
    if group == PINNED_ID then table.insert(pinned, api.nvim_buf_get_name(buf)) end
  end

  if #pinned == 0 then
    vim.g[PINNED_KEY] = ""
  else
    vim.g[PINNED_KEY] = table.concat(pinned, ",")
  end
end

---@param element bufferline.TabElement
---@return string
local function get_manual_group(element) return group_state.manual_groupings[element.id] end

--------------------------------
--- @Remove Group feature added, simply moves a buffer from the group to the ungrouped group

--- @param buffer_id integer
local function move_buffer_to_ungrouped(buffer_id, from_group_id)
  local ungrouped_index
  local buffer_to_move
  for i, group in ipairs(group_state.components_by_group) do
    if group.id == from_group_id then
      for j, buf in ipairs(group) do
        if buf.id == buffer_id then
          buffer_to_move = table.remove(group, j)
          break
        end
      end
    elseif group.id == "ungrouped" then
      ungrouped_index = i
    end
  end
  if buffer_to_move and ungrouped_index then
    table.insert(group_state.components_by_group[ungrouped_index], buffer_to_move)
  end

  -- Update manual_groupings if it exists
  if group_state.manual_groupings then group_state.manual_groupings[buffer_id] = nil end
end

--- Remove a buffer from the group - public function
--- @param buf_id integer
--- @param group_id string
function M.remove_buf_from_group(buf_id, group_id) move_buffer_to_ungrouped(buf_id, group_id) end

--------------------------------

--- Wrapper to abstract interacting directly with manual groups as the access mechanism
-- can vary i.e. buffer id or path and this should be changed in a centralised way.
---@param id number
---@param group_id string?
local function set_manual_group(id, group_id) group_state.manual_groupings[id] = group_id end

---A temporary helper to inform user of the full buffer object that using it's full value is deprecated.
---@param obj table
---@return table
local function with_deprecation(obj)
  return setmetatable(obj, {
    __index = function(_, k)
      vim.schedule(function()
        -- stylua: ignore
        vim.deprecate(k, "the buffer ID to get any other value option you need", "v4.0.0", "bufferline")
      end)
    end,
  })
end

---Group buffers based on user criteria
---buffers only carry a copy of the group ID which is then used to retrieve the correct group
---@param buffer bufferline.Buffer
---@return string?
function M.set_id(buffer)
  if vim.tbl_isempty(group_state.user_groups) then return end
  local manual_group = get_manual_group(buffer)
  if manual_group then return manual_group end
  for id, group in pairs(group_state.user_groups) do
    if type(group.matcher) == "function" then
      local matched = group.matcher(with_deprecation({
        id = buffer.id,
        name = buffer.name,
        path = buffer.path,
        modified = buffer.modified,
        buftype = buffer.buftype,
      }))
      if matched then return id end
    end
  end
  return UNGROUPED_ID
end

---@param id string
---@return bufferline.Group
function M.get_by_id(id) return group_state.user_groups[id] end

--- Create an empty list of size n to store sorted buffers for each Group
--- This will store the buffers for the groups according to priority
--- @param size integer
--- @return table<integer,any>
local function generate_sublists(size)
  local list = {}
  for i = 1, size do
    list[i] = {}
  end
  return list
end

--- Converts the component to a Segment with group styles applied
---Add group styling to the buffer component
---@param ctx bufferline.RenderContext
---@return bufferline.Segment?
function M.component(ctx)
  local element = ctx.tab
  local hls = ctx.current_highlights
  local group = group_state.user_groups[element.group]
  if not group then return end
  local group_hl = hls[group.name]
  local hl = group_hl or hls.buffer
  if not group.icon then return nil end
  local extends = { { id = ui.components.id.name } }
  if group_hl then extends[#extends + 1] = { id = ui.components.id.duplicates } end
  return { text = group.icon, highlight = hl, attr = { extends = extends } }
end

--- Pull pinned buffers saved in a vim.g global variable and restore them
--- to the manual_groupings table.
local function restore_pinned_buffers()
  local pinned = vim.g[PINNED_KEY]
  if not pinned then return end
  local manual_groupings = vim.split(pinned, ",") or {}
  for _, path in ipairs(manual_groupings) do
    local buf_id = fn.bufnr(path --[[@as integer]])
    if buf_id ~= -1 then
      set_manual_group(buf_id, PINNED_ID)
      persist_pinned_buffers()
    end
  end
  ui.refresh()
end

--- Initialize the group sep settings from the config
---@param conf bufferline.UserConfig
local function initialize_group_separators(conf)
  local group_sep_type = vim.tbl_get(conf, "options", "groups", "options", "separator_position") or ""
  if group_sep_type then group_sep_position = group_sep_type end

  local separator_style = vim.tbl_get(conf, "options", "groups", "options", "separator_style") or "none"

  if separator_style == "thick" then
    group_sep_left = "▎"
    group_sep_right = "▎"
  elseif separator_style == "thin" then
    group_sep_left = "▏"
    group_sep_right = "▏"
  elseif type(separator_style) == "table" and #separator_style == 2 then
    group_sep_left = separator_style[1]
    group_sep_right = separator_style[2]
  end
end

--- NOTE: this function mutates the user's configuration by adding group highlights to the user highlights table.
---@param conf bufferline.UserConfig
function M.setup(conf)
  if not conf then return end
  local groups = vim.tbl_get(conf, "options", "groups", "items") or {} ---@type bufferline.Group[]
  -- if the user has already set the pinned builtin themselves
  -- then we want each group to have a priority based on it's position in the list
  -- otherwise we want to shift the priorities of their groups by 1 to accommodate the pinned group
  local has_set_pinned = not vim.tbl_isempty(vim.tbl_filter(function(group) return group.id == PINNED_ID end, groups))

  -- new: check if the user wants the sep to appear before the group bufs or after or both
  initialize_group_separators(conf)

  -- if pinned is set - pinned priority is always 1
  -- hence group priorities start from 1..n , n <- number of groups defined
  for index, current in ipairs(groups) do
    local priority = has_set_pinned and index or index + 1
    local group = Group:new(current, priority)
    group_state.user_groups[group.id] = group
  end

  -- We only set the builtin groups after we know what the user has configured
  if not group_state.user_groups[PINNED_ID] then group_state.user_groups[PINNED_ID] = builtin.pinned end
  if not group_state.user_groups[UNGROUPED_ID] then
    group_state.user_groups[UNGROUPED_ID] = builtin.ungrouped:with({
      priority = vim.tbl_count(group_state.user_groups) + 1,
    })
  end
  -- Restore pinned buffer from the previous session
  api.nvim_create_autocmd("SessionLoadPost", { once = true, callback = restore_pinned_buffers })
end

---Execute a command on each buffer of a group
---@param group_name string
---@param callback fun(b: bufferline.Buffer)
local function command(group_name, callback)
  local group = utils.find(function(list) return list.name == group_name end, group_state.components_by_group)
  if not group then return end
  utils.for_each(callback, group)
end

---@generic T
---@param attr string
---@return fun(arg: T): bufferline.Group
local function group_by(attr)
  return function(value)
    for _, grp in pairs(group_state.user_groups) do
      if grp[attr] == value then return grp end
    end
  end
end

local group_by_name = group_by("name")
local group_by_priority = group_by("priority")

---@param element bufferline.TabElement
function M._is_pinned(element) return get_manual_group(element) == PINNED_ID end

--- Add a buffer to a group manually
---@param group_name string
---@param element bufferline.TabElement?
function M.add_element(group_name, element)
  local group = group_by_name(group_name)
  if group and element then
    set_manual_group(element.id, group.id)
    persist_pinned_buffers()
  end
end

---@param group_name string
---@param element bufferline.TabElement
function M.remove_element(group_name, element)
  local group = group_by_name(group_name)
  if group then
    local id = get_manual_group(element)
    set_manual_group(element.id, id ~= group.id and id or nil)
    if group_name == PINNED_ID then persist_pinned_buffers() end
  end
end

---@param id number
function M.remove_id_from_manual_groupings(id) group_state.manual_groupings[id] = nil end

---@param id string
---@param value boolean
function M.set_hidden(id, value)
  assert(id, "You must pass in a group ID to set its state")
  local group = group_state.user_groups[id]
  if group then group.hidden = value end
end

--- Keeping track of minimized buffer groups solves the BufferLineCycle bug when active tab is minimized
---@param priority number?
---@param name string?
function M.toggle_hidden(priority, name)
  local group = priority and group_by_priority(priority) or group_by_name(name)
  if group then
    if not group.hidden then
      update_toggled(1)
    else
      update_toggled(-1)
    end
    group.hidden = not group.hidden
  end
end

---Get the names for all bufferline groups
---@param include_empty boolean?
---@return string[]
local function names(include_empty)
  if not group_state.user_groups then return {} end
  local result = {}
  for _, group in pairs(group_state.components_by_group) do
    if include_empty or (group and #group > 0) then table.insert(result, group.name) end
  end
  return result
end

---@param arg_lead string
---@param cmd_line string
---@param cursor_pos number
---@return string[]
---@diagnostic disable-next-line: unused-local
function M.complete(arg_lead, cmd_line, cursor_pos) return names() end

--- Draw the separator start component for a group
---@param group bufferline.Group
---@param hls bufferline.Highlights?
---@param count number
---@return bufferline.Separators
local function create_indicator(group, hls, count)
  hls = hls or {}

  local count_item = group.hidden and fmt("(%s)", count) or ""
  local seps = group.separator.style(group, hls, count_item)

  if seps.sep_start then
    table.insert(seps.sep_start, ui.make_clickable("handle_group_click", group.priority, { attr = { global = true } }))
  end

  return seps
end

--- Once sorting is done and we have the components and clustered by group
--- Create the start/end visual indicators for each group

---Create the visual indicators bookending buffer groups
---@param group_id string
---@param components bufferline.Component[]
---@return bufferline.Component?
---@return bufferline.Component?
local function get_group_marker(group_id, components)
  local group = group_state.user_groups[group_id]
  if not group then return end
  local GroupView = models.GroupView
  local hl_groups = config.highlights

  group.separator = group.separator or {}
  --- NOTE: the default buffer group style is the pill
  group.separator.style = group.separator.style or separator.pill
  if not group.separator.style then return end

  local seps = create_indicator(group, hl_groups, #components)
  local s_start, s_end = seps.sep_start, seps.sep_end
  local group_start, group_end
  local s_start_length = ui.get_component_size(s_start)
  local s_end_length = ui.get_component_size(s_end)
  if s_start_length > 0 then
    group_start = GroupView:new({
      type = "group_start",
      length = s_start_length,
      component = function() return s_start end,
    })
  end
  if s_end_length > 0 then
    group_end = GroupView:new({
      type = "group_end",
      length = s_end_length,
      component = function() return s_end end,
    })
  end
  return group_start, group_end
end

--- The aim is to have buffers easily accessible by key as well as a list of sorted and prioritized
--- buffers for things like navigation. This function takes advantage of lua's ability
--- to sort string keys as well as numerical keys in a table, this way each sublist has
--- not only the group information but contains it's buffers
---@param components bufferline.Component[]
---@return bufferline.Component[], bufferline.ComponentsByGroup
local function sort_by_groups(components)
  local sorted = {}
  local clustered = generate_sublists(vim.tbl_count(group_state.user_groups))
  -- for each buffer - get it's group id
  for index, tab in ipairs(components) do
    local buf = tab:as_element()
    if buf then
      -- get sublist the buf is supposed to be in
      local group = group_state.user_groups[buf.group]
      local sublist = clustered[group.priority]

      if not sublist.name then
        sublist.id = group.id
        sublist.name = group.name
        sublist.priorty = group.priority
        sublist.hidden = group.hidden
        sublist.display_name = group.display_name
      end
      table.insert(sublist, { id = buf.id, index = index })
      table.insert(sorted, buf)
    end
  end

  -- sorted is all components ordered
  return sorted, clustered
end

function M.get_all() return group_state.user_groups end

---@alias group_actions "close" | "toggle"
---Execute an action on a group of buffers
---@param name string
---@param action group_actions | fun(b: bufferline.Buffer)
function M.action(name, action)
  assert(name, "A name must be passed to execute a group action")
  if action == "close" then
    command(name, function(b) api.nvim_buf_delete(b.id, { force = true }) end)
    ui.refresh()
    if name == PINNED_NAME then vim.g[PINNED_KEY] = {} end
    for buf, group_id in pairs(group_state.manual_groupings) do
      if group_id == name then group_state.manual_groupings[buf] = nil end
    end
  elseif action == "toggle" then
    M.toggle_hidden(nil, name)
    ui.refresh()
  elseif type(action) == "function" then
    command(name, action)
  end
end

function M.toggle_pin()
  local _, element = commands.get_current_element_index(state)
  if not element then return end
  if M._is_pinned(element) then
    M.remove_element("pinned", element)
  else
    M.add_element("pinned", element)
  end
  ui.refresh()
end

function M.handle_group_enter()
  local options = config.options
  local _, element = commands.get_current_element_index(state, { include_hidden = true })
  if not element or not element.group then return end
  local current_group = M.get_by_id(element.group)
  if options.groups.options.toggle_hidden_on_enter then
    if current_group.hidden then M.set_hidden(current_group.id, false) end
  end
  utils.for_each(function(tab)
    local group = M.get_by_id(tab.group)
    if group and group.auto_close and group.id ~= current_group.id then M.set_hidden(group.id, true) end
  end, state.components)
end

--- @class UserGroup
--- @field id  string
--- @field name string
--- @field priority integer
--- @field hidden boolean
--- @field display_name string

---@class BufferInfo
---@field id number
---@field index number

--- @class GroupBuffers
--- @field id string
--- @field name string
--- @field priority integer
--- @field hidden boolean
--- @field display_name string
--- @field [integer] BufferInfo

--- @alias UserGroups table<integer, GroupBuffers>

--- Get the buffer group from the tab/buf - and return the priority as we use Priority to index our user groups.
--- using priority gives us the index where the buffers will be placed
--- @param buf bufferline.Buffer|bufferline.Tab
local function get_buf_group_and_priority(buf)
  local buf_group = group_state.user_groups[buf.group]
  return buf_group, buf_group.priority
end

--- If the user group containing buffers is fresh (has no name,display name..) - set the fields from the child buffer
--- @param usergroup GroupBuffers
--- @param buf bufferline.Buffer|bufferline.Tab
local function set_usergroup_fields(usergroup, buf)
  if not usergroup.name then
    local buf_group = group_state.user_groups[buf.group]
    usergroup.id = buf_group.id
    usergroup.name = buf_group.name
    usergroup.priority = buf_group.priority
    usergroup.hidden = buf_group.hidden
    usergroup.display_name = buf_group.display_name
  end
end

--- Creates a UserGroups container to store each Group info and a List of the buffers
--- @return  UserGroups
local function create_user_groups_list()
  local user_groups = {}
  local size = vim.tbl_count(group_state.user_groups)
  for i = 1, size do
    user_groups[i] = {}
  end
  return user_groups
end

--- @param usergroup UserGroup
--- @param result bufferline.Component[]
local function insert_group_with_start_end(usergroup, result)
  if #usergroup > 0 then
    local group_start, group_end = get_group_marker(usergroup.id, usergroup)
    if group_start then table.insert(result, group_start) end
    for _, tab in ipairs(usergroup) do
      table.insert(result, tab)
    end
    if group_end then table.insert(result, group_end) end
  end
end

-- FIXME: this function does a lot of looping that can maybe be consolidated
--- The function as it is - called in render() - with redundancy and indirection
---@param components bufferline.Component[]
---@return bufferline.Component[]
local function render_old(components, sorter)
  local sorted = {}

  local clustered = {}

  local size = vim.tbl_count(group_state.user_groups)
  for i = 1, size do
    clustered[i] = {}
  end

  for index, tab in ipairs(components) do
    local buf = tab:as_element()
    if buf then
      local buf_group = group_state.user_groups[buf.group]
      local buf_container = clustered[buf_group.priority]
      if not buf_container.name then
        buf_container.id = buf_group.id
        buf_container.name = buf_group.name
        buf_container.priority = buf_group.priority
        buf_container.hidden = buf_group.hidden
        buf_container.display_name = buf_group.display_name
      end
      table.insert(buf_container, { id = buf.id, index = index })
      table.insert(sorted, buf)
    end
  end

  group_state.components_by_group = clustered

  if vim.tbl_isempty(clustered) then return sorted end
  local result = {} ---@type bufferline.Component[]
  for _, group_buf_infos in ipairs(clustered) do
    local buf_group_id = group_buf_infos.id
    local buf_group = group_state.user_groups[buf_group_id]

    local items = {}

    for index, item in ipairs(group_buf_infos) do
      local t = components[item.index]
      t.hidden = buf_group and buf_group.hidden
      items[index] = t
    end

    items = sorter(items)

    if #group_buf_infos > 0 then
      local group_start, group_end = get_group_marker(group_buf_infos.id, group_buf_infos)
      if group_start then
        table.insert(items, 1, group_start)
        items[#items + 1] = group_end
      end
    end
    result = utils.merge_lists(result, items)
  end

  return result
end

--- Revamped logic without redundant looping
---@param components bufferline.Component[]
---@return bufferline.Component[]
local function render_new(components, sorter)
  local clustered = {}
  local size = vim.tbl_count(group_state.user_groups)
  for i = 1, size do
    clustered[i] = {}
  end
  for i, tab in ipairs(components) do
    local buf = tab:as_element()
    if buf then
      local buf_group = group_state.user_groups[buf.group]
      local buf_container = clustered[buf_group.priority]
      if not buf_container.name then
        buf_container.id = buf_group.id
        buf_container.name = buf_group.name
        buf_container.priority = buf_group.priority
        buf_container.hidden = buf_group.hidden
        buf_container.display_name = buf_group.display_name
      end
      tab.hidden = buf_group.hidden
      table.insert(buf_container, tab)
      -- table.insert(buf_container, { id = buf.id, index = i}) (only stores bufid , index}
    end
  end

  -- how relevant is doing this once we update the user groups
  -- I am assuming we only want to store the index and id here - in the below version
  -- that is what I added , this function just has all the logic laid out
  group_state.components_by_group = clustered

  if vim.tbl_isempty(clustered) then return components end

  local result = {} ---@type bufferline.Component[]

  for _, group_buf_infos in ipairs(clustered) do
    group_buf_infos = sorter(group_buf_infos)

    if #group_buf_infos > 0 then
      local group_start, group_end = get_group_marker(group_buf_infos.id, group_buf_infos)
      if group_start then table.insert(result, group_start) end
      for _, tab in ipairs(group_buf_infos) do
        table.insert(result, tab)
      end
      if group_end then table.insert(result, group_end) end
    end
  end
  return result
end

--- Revamped logic without redundant looping , using functions (same as render_new)
---@param components bufferline.Component[]
---@return bufferline.Component[]
local function render_clean(components, sorter)
  local user_groups = create_user_groups_list()

  -- since we store only the id and name in the persistent component state, use this for the local state
  local user_groups_minimal = create_user_groups_list()

  for index, tab in ipairs(components) do
    local buf = tab:as_element()
    if buf then
      local buf_group, priority = get_buf_group_and_priority(buf)
      local user_group, minimal = user_groups[priority], user_groups_minimal[priority]
      if not user_group.name then
        set_usergroup_fields(user_group, buf)
        set_usergroup_fields(minimal, buf)
      end
      tab.hidden = buf_group.hidden -- if the group is hidden - set tab to be hidden too
      table.insert(user_group, tab)
      table.insert(minimal, { id = buf.id, index = index })
    end
  end

  -- Set Group State with the minimal table that only has id and index for buffers
  group_state.components_by_group = user_groups_minimal

  if vim.tbl_isempty(user_groups) then return components end
  local result = {} ---@type bufferline.Component[]
  for _, usergroup in ipairs(user_groups) do
    usergroup = sorter(usergroup) -- No Op
    if #usergroup > 0 then insert_group_with_start_end(usergroup, result) end
  end
  return result
end

-- v1 original - uses sort_by_groups_v1
---@param components bufferline.Component[]
---@param sorter fun(list: bufferline.Component[]):bufferline.Component[]
---@return bufferline.Component[]
function M.render(components, sorter) return render_clean(components, sorter) end

M.builtin = builtin
M.separator = separator

if utils.is_test() then
  M.state = group_state
  M.sort_by_groups = sort_by_groups
  M.get_manual_group = get_manual_group
  M.set_manual_group = set_manual_group
end

return M
