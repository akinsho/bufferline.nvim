local lazy = require("bufferline.lazy")
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local models = lazy.require("bufferline.models") ---@module "bufferline.models"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"
local commands = lazy.require("bufferline.commands") ---@module "bufferline.commands"
local state = lazy.require("bufferline.state") ---@module "bufferline.state"
local C = lazy.require("bufferline.constants") ---@module "bufferline.constants"

local fn = vim.fn

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
local separator = {}

local function space_end(hl_groups) return { { highlight = hl_groups.fill.hl_group, text = C.padding } } end

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
  local indicator = {
    { text = C.padding, highlight = bg_hl },
    { text = left, highlight = sep_hl },
    { text = display_name .. count, highlight = label_hl },
    { text = right, highlight = sep_hl },
    { text = C.padding, highlight = bg_hl },
  }
  return { sep_start = indicator, sep_end = space_end(hls) }
end

---@param group bufferline.Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return bufferline.Separators
---@type GroupSeparator
function separator.tab(group, hls, count)
  local hl = hls.fill.hl_group
  local indicator_hl = hls.buffer.hl_group
  local indicator = {
    { highlight = hl, text = C.padding },
    { highlight = indicator_hl, text = C.padding .. group.name .. count .. C.padding },
    { highlight = hl, text = C.padding },
  }
  return { sep_start = indicator, sep_end = space_end(hls) }
end

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
  o = o or { priority = index }
  self.__index = self
  local name = format_name(o.name)
  o = vim.tbl_extend("force", o, {
    id = o.id or name,
    hidden = o.hidden == nil and false or o.hidden,
    name = name,
    display_name = o.name,
    priority = o.priority or index,
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

local function generate_sublists(size)
  local list = {}
  for i = 1, size do
    list[i] = {}
  end
  return list
end

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
  return {
    text = group.icon,
    highlight = hl,
    attr = { extends = extends },
  }
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

--- NOTE: this function mutates the user's configuration by adding group highlights to the user highlights table.
---
---@param conf bufferline.UserConfig
function M.setup(conf)
  if not conf then return end
  local groups = vim.tbl_get(conf, "options", "groups", "items") or {} ---@type bufferline.Group[]

  -- if the user has already set the pinned builtin themselves
  -- then we want each group to have a priority based on it's position in the list
  -- otherwise we want to shift the priorities of their groups by 1 to accommodate the pinned group
  local has_set_pinned = not vim.tbl_isempty(vim.tbl_filter(function(group) return group.id == PINNED_ID end, groups))

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

---@param priority number?
---@param name string?
function M.toggle_hidden(priority, name)
  local group = priority and group_by_priority(priority) or group_by_name(name)
  if group then group.hidden = not group.hidden end
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
  for index, tab in ipairs(components) do
    local buf = tab:as_element()
    if buf then
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

-- FIXME: this function does a lot of looping that can maybe be consolidated
--
---@param components bufferline.Component[]
---@param sorter fun(list: bufferline.Component[]):bufferline.Component[]
---@return bufferline.Component[]
function M.render(components, sorter)
  components, group_state.components_by_group = sort_by_groups(components)
  if vim.tbl_isempty(group_state.components_by_group) then return components end
  local result = {} ---@type bufferline.Component[]
  for _, sublist in ipairs(group_state.components_by_group) do
    local buf_group_id = sublist.id
    local buf_group = group_state.user_groups[buf_group_id]
    --- convert our components by group which is essentially and index of tab positions and ids
    --- to the actual tab by pulling the full value out of the tab map
    local items = utils.map(function(map)
      local t = components[map.index]
      --- filter out tab views that are hidden
      t.hidden = buf_group and buf_group.hidden
      return t
    end, sublist)
    --- Sort *each* group, TODO: in the future each group should be able to have it's own sorter
    items = sorter(items)

    if #sublist > 0 then
      local group_start, group_end = get_group_marker(buf_group_id, sublist)
      if group_start then
        table.insert(items, 1, group_start)
        items[#items + 1] = group_end
      end
    end
    result = utils.merge_lists(result, items)
  end
  return result
end

M.builtin = builtin
M.separator = separator

if utils.is_test() then
  M.state = group_state
  M.sort_by_groups = sort_by_groups
  M.get_manual_group = get_manual_group
  M.set_manual_group = set_manual_group
end

return M
