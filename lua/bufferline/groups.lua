local lazy = require("bufferline.lazy")
--- @module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
--- @module "bufferline.constants"
local padding = lazy.require("bufferline.constants").padding
--- @module "bufferline.models"
local models = lazy.require("bufferline.models")

----------------------------------------------------------------------------------------------------
-- Types
----------------------------------------------------------------------------------------------------

--- @class GroupState
--- @field manual_groupings table<string, Group>
--- @field user_groups table<string, Group>
--- @field components_by_group table<string,number>[][]

--- @class Separator
--- @field component string
--- @field length number

--- @class Separators
--- @field sep_start Separator
--- @field sep_end Separator

---@alias GroupSeparator fun(name: string, group:Group, hls: BufferlineHLGroup, count_item: string): Separators
---@alias GroupSeparators table<string, GroupSeparator>
---@alias grouper fun(b: Buffer): boolean

---@class Group
---@field public id number used for identifying the group in the tabline
---@field public name string 'formatted name of the group'
---@field public display_name string original name including special characters
---@field public matcher grouper
---@field public separator GroupSeparators
---@field public priority number
---@field public highlight table<string, string>
---@field public icon string
---@field public hidden boolean
---@field public index number the position of the group
---@field auto_close boolean when leaving the group automatically close it

----------------------------------------------------------------------------------------------------
-- CONSTANTS
----------------------------------------------------------------------------------------------------

local PINNED_ID = "pinned"
local PINNED_NAME = "pinned"
local UNGROUPED_NAME = "ungrouped"
local UNGROUPED_ID = "ungrouped"

local api = vim.api
local fmt = string.format
local strwidth = api.nvim_strwidth

local M = {
  separator = {},
  ---@type table<string, Group>
  builtin = {},
}

----------------------------------------------------------------------------------------------------
-- SEPARATORS
----------------------------------------------------------------------------------------------------

local function space_end(hl_groups)
  return { component = utils.join(hl_groups.fill.hl, padding), length = strwidth(padding) }
end

---@param group Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return string, number
function M.separator.pill(group, hls, count)
  local bg_hl = hls.fill.hl
  local name, display_name = group.name, group.display_name
  local sep_grp, label_grp = hls[fmt("%s_separator", name)], hls[fmt("%s_label", name)]
  local sep_hl = sep_grp and sep_grp.hl or hls.group_separator.hl
  local label_hl = label_grp and label_grp.hl or hls.group_label.hl
  local left, right = "█", "█"
  local indicator = utils.join(
    bg_hl,
    padding,
    sep_hl,
    left,
    label_hl,
    display_name,
    count,
    sep_hl,
    right,
    padding
  )
  local length = utils.measure(left, right, display_name, count, padding, padding)
  return { sep_start = { component = indicator, length = length }, sep_end = space_end(hls) }
end

---@param name string,
---@param hls  table<string, table<string, string>>
---@param count string
---@return string, number
---@type GroupSeparator
function M.separator.tab(name, hls, count)
  local hl = hls.fill.hl
  local indicator_hl = hls.buffer.hl
  local length = utils.measure(name, string.rep(padding, 4), count)
  local indicator = utils.join(hl, padding, indicator_hl, padding, name, count, hl, padding)
  return { sep_start = { component = indicator, length = length }, sep_end = space_end(hls) }
end

---@type GroupSeparator
function M.separator.none()
  return { sep_start = { component = "", length = 0 }, sep_end = { component = "", length = 0 } }
end

----------------------------------------------------------------------------------------------------
-- BUILTIN GROUPS
----------------------------------------------------------------------------------------------------

M.builtin.ungrouped = {
  id = UNGROUPED_ID,
  name = UNGROUPED_NAME,
  separator = {
    style = M.separator.none,
  },
}

M.builtin.pinned = {
  id = PINNED_ID,
  name = PINNED_NAME,
  icon = "📌",
  priority = 1,
  separator = {
    style = M.separator.none,
  },
}

----------------------------------------------------------------------------------------------------
-- STATE
----------------------------------------------------------------------------------------------------

--- @type GroupState
local state = {
  -- A table of buffers mapped to a specific group by a user
  manual_groupings = {},
  user_groups = {},
  --- Represents a list of maps of type `{id = buf_id, index = position in list}`
  --- so that rather than storing the components we store their positions
  --- with an easy way to look them up later.
  --- e.g. `[[group 1, {id = 12, index = 1}, {id = 10, index 2}], [group 2, {id = 5, index = 3}]]`
  components_by_group = {},
}

--- Remove illegal characters from a group name name
---@param name string
local function format_name(name)
  return name:gsub("[^%w]+", "_")
end

---Group buffers based on user criteria
---buffers only carry a copy of the group ID which is then used to retrieve the correct group
---@param buffer Buffer
function M.set_id(buffer)
  if vim.tbl_isempty(state.user_groups) then
    return
  end
  if state.manual_groupings[buffer.path] then
    return state.manual_groupings[buffer.path]
  end
  for id, group in pairs(state.user_groups) do
    if type(group.matcher) == "function" and group.matcher(buffer) then
      return id
    end
  end
  return UNGROUPED_ID
end

---@param id number
---@return Group
function M.get_by_id(id)
  return state.user_groups[id]
end

local function generate_sublists(size)
  local list = {}
  for i = 1, size do
    list[i] = {}
  end
  return list
end

---Add group styling to the buffer component
---@param ctx RenderContext
---@return string
---@return number
function M.component(ctx)
  local element = ctx.tab
  local hls = ctx.current_highlights
  local group = state.user_groups[element.group]
  if not group then
    return ctx
  end
  --- TODO: should there be default icons at all
  local icon = group.icon and group.icon .. padding or ""
  local icon_length = api.nvim_strwidth(icon)
  local hl = hls[group.name] or ""
  local component, length = hl .. icon .. ctx.component .. hls.buffer.hl, ctx.length + icon_length
  return ctx:update({ component = component, length = length })
end

---Add extra metadata to each group
---@param index number
---@param group Group
---@return Group
local function enrich_group(index, group)
  group = group or { priority = index }
  local name = format_name(group.name)
  return vim.tbl_extend("force", group, {
    index = index,
    id = group.id or name,
    hidden = group.hidden == nil and false or group.hidden,
    name = name,
    display_name = group.name,
    priority = group.priority or index,
  })
end

---Add highlight groups for a group
---@param name string
---@param group Group
---@param hls BufferlineHighlights
local function set_group_highlights(name, group, hls)
  local hl = group.highlight
  if not hl or type(hl) ~= "table" then
    return
  end
  hls[fmt("%s_separator", name)] = {
    guifg = hl.guifg or hl.guisp or hls.group_separator.guifg,
    guibg = hls.fill.guibg,
  }
  hls[fmt("%s_label", name)] = {
    guifg = hls.fill.guibg,
    guibg = hl.guifg or hl.guisp or hls.group_separator.guifg,
  }
  hls[fmt("%s_selected", name)] = vim.tbl_extend("keep", hl, hls.buffer_selected)
  hls[fmt("%s_visible", name)] = vim.tbl_extend("keep", hl, hls.buffer_visible)
  hls[name] = vim.tbl_extend("keep", hl, hls.buffer)
end

---@param highlights BufferlineHighlights
function M.reset_highlights(highlights)
  utils.for_each(state.user_groups, function(item)
    set_group_highlights(item.name, item, highlights)
  end)
end

--- NOTE: this function mutates the user's configuration.
--- Add group highlights to the user highlights table
---@param config BufferlineConfig
function M.setup(config)
  if not config then
    return
  end

  local hls = config.highlights
  local groups = config.options.groups.items
  table.insert(groups, 1, M.builtin.pinned)

  local result = utils.fold({ ungrouped_seen = false, map = {} }, function(accum, group, index)
    accum.ungrouped_seen = accum.ungrouped_seen or group.id == UNGROUPED_ID
    group = enrich_group(index, group)
    accum.map[group.id] = group
    -- track if the user has specified an ungrouped group because if they haven't we must add one
    -- on the final iteration of the loop
    if index == #groups and not accum.ungrouped_seen then
      local ungrouped = enrich_group(index + 1, M.builtin.ungrouped)
      accum.map[ungrouped.id] = ungrouped
    end
    set_group_highlights(group.name, group, hls)
    return accum
  end, groups)
  state.user_groups = result.map
end

--- Add the current highlight for a specific buffer
--- NOTE: this function mutates the current highlights.
---@param buffer Buffer
---@param highlights table<string, table<string, string>>
---@param current_hl table<string, string>
function M.set_current_hl(buffer, highlights, current_hl)
  local group = state.user_groups[buffer.group]
  if not group or not group.name or not group.highlight then
    return
  end
  local name = group.name
  local hl_name = buffer:current() and fmt("%s_selected", name)
    or buffer:visible() and fmt("%s_visible", name)
    or name
  current_hl[name] = highlights[hl_name].hl
end

---Execute a command on each buffer of a group
---@param group_name string
---@param callback fun(b: Buffer)
function M.command(group_name, callback)
  local group = utils.find(state.components_by_group, function(list)
    return list.name == group_name
  end)
  utils.for_each(group, callback)
end

---@generic T
---@param attr string
---@return fun(arg: T): Group
local function group_by(attr)
  return function(value)
    for _, grp in pairs(state.user_groups) do
      if grp[attr] == value then
        return grp
      end
    end
  end
end

local group_by_name = group_by("name")
local group_by_priority = group_by("priority")

---@param buffer Buffer
function M.is_pinned(buffer)
  return state.manual_groupings[buffer.path] == PINNED_ID
end

--- Add a buffer to a group manually
---@param group_name string
---@param buffer Buffer
function M.add_to_group(group_name, buffer)
  local group = group_by_name(group_name)
  if group then
    state.manual_groupings[buffer.path] = group.id
  end
end

---@param group_name string
---@param buffer Buffer
function M.remove_from_group(group_name, buffer)
  local group = group_by_name(group_name)
  if group then
    local id = state.manual_groupings[buffer.path]
    state.manual_groupings[buffer.path] = id ~= group.id and id or nil
  end
end

---@param id string
---@param value boolean
function M.set_hidden(id, value)
  assert(id, "You must pass in a group ID to set its state")
  local group = state.user_groups[id]
  if group then
    group.hidden = value
  end
end

---@param priority number
---@param name string
function M.toggle_hidden(priority, name)
  local group = priority and group_by_priority(priority) or group_by_name(name)
  if group then
    group.hidden = not group.hidden
  end
end

---Get the names for all bufferline groups
---@param include_empty boolean
---@return string[]
function M.names(include_empty)
  if state.user_groups == nil then
    return {}
  end
  local names = {}
  for _, group in ipairs(state.user_groups) do
    local group_components = utils.find(state.components_by_group, function(item)
      return item.id == group.id
    end)
    if include_empty or (group_components and #group_components > 0) then
      table.insert(names, group.name)
    end
  end
  return names
end

--- Draw the separator start component for a group
---@param group Group
---@param hls BufferlineHighlights
---@param count number
---@return Separators
local function create_indicator(group, hls, count)
  local count_item = group.hidden and fmt("(%s)", count) or ""
  local seps = group.separator.style(group, hls, count_item)
  if seps.sep_start.length > 0 then
    seps.sep_start.component = utils.make_clickable(
      "handle_group_click",
      group.priority,
      seps.sep_start.component
    )
  end
  return seps
end

---Create the visual indicators bookending buffer groups
---@param group_id number
---@param components Component[]
---@return Component
---@return Component
local function get_group_marker(group_id, components)
  local group = state.user_groups[group_id]
  if not group then
    return
  end
  local GroupView = models.GroupView
  local hl_groups = require("bufferline.config").get("highlights")

  group.separator = group.separator or {}
  --- NOTE: the default buffer group style is the pill
  group.separator.style = group.separator.style or M.separator.pill
  if not group.separator.style then
    return
  end

  local seps = create_indicator(group, hl_groups, #components)
  local s_start, s_end = seps.sep_start, seps.sep_end
  local group_start = GroupView:new({
    type = "group_start",
    length = s_start.length,
    component = function()
      return s_start.component
    end,
  })
  local group_end = GroupView:new({
    type = "group_end",
    length = s_end.length,
    component = function()
      return s_end.component
    end,
  })
  return group_start, group_end
end

--- The aim is to have buffers easily accessible by key as well as a list of sorted and prioritized
--- buffers for things like navigation. This function takes advantage of lua's ability
--- to sort string keys as well as numerical keys in a table, this way each sublist has
--- not only the group information but contains it's buffers
---@param components Component[]
---@return Component[]
local function sort_by_groups(components)
  local sorted = {}
  local clustered = generate_sublists(vim.tbl_count(state.user_groups))
  for index, tab in ipairs(components) do
    local buf = tab:as_element()
    if buf then
      local group = state.user_groups[buf.group]
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

-- FIXME:
-- 1. this function does a lot of looping that can maybe be consolidated
---@param components Component[]
---@param sorter fun(list: Component[]):Component[]
---@return Component[]
function M.render(components, sorter)
  components, state.components_by_group = sort_by_groups(components)
  if vim.tbl_isempty(state.components_by_group) then
    return components
  end
  local result = {}
  for _, sublist in ipairs(state.components_by_group) do
    local buf_group_id = sublist.id
    local buf_group = state.user_groups[buf_group_id]
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
    --- NOTE: there is no easy way to flatten a list of lists of non-scalar values like these
    --- lists of objects since each object needs to be checked that it is in fact an object
    --- not a list
    vim.list_extend(result, items)
  end
  return result
end

if utils.is_test() then
  M.state = state
  M.sort_by_groups = sort_by_groups
end

return M
