local M = { separator = {} }
local api = vim.api

local fmt = string.format
local strwidth = api.nvim_strwidth
local utils = require("bufferline.utils")
local padding = require("bufferline.constants").padding

---@type table<string, Group>
local user_groups = {}

---@type TabView[][]
local tabs_by_group = {}

local UNGROUPED = "ungrouped"

---@alias GroupSeparator fun(name: string, group:Group, hls: table<string, table<string, string>>, count_item: string): string, number
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

--- Remove illegal characters from a group name name
---@param name string
local function format_name(name)
  return name:gsub("%s+", "_")
end

---Group buffers based on user criteria
---buffers only carry a copy of the group ID which is then used to retrieve the correct group
---@param buffer Buffer
function M.get_group_id(buffer)
  if not user_groups or vim.tbl_isempty(user_groups) then
    return
  end
  local ungrouped_id
  for id, group in pairs(user_groups) do
    ungrouped_id = group.name == UNGROUPED and id or nil
    if type(group.matcher) == "function" and group.matcher(buffer) then
      return id
    end
  end
  -- Assign the buffer to the ungrouped group since it matches nohing else
  return ungrouped_id
end

local function generate_sublists(size)
  local list = {}
  for i = 1, size do
    list[i] = {}
  end
  return list
end

--- Save the current buffer groups
--- The aim is to have buffers easily accessible by key as well as a list of sorted and prioritized
--- buffers for things like navigation. This function takes advantage of lua's ability
--- to sort string keys as well as numerical keys in a table, this way each sublist has
--- not only the group information but contains it's buffers
---@param buffers Buffer[]
---@return Buffer[]
function M.sort_by_groups(buffers)
  local no_of_groups = vim.tbl_count(user_groups)
  local list = generate_sublists(no_of_groups)
  local sublists = utils.fold(list, function(accum, buf)
    local group = user_groups[buf.group]
    local sublist = accum[group.priority]
    if not sublist.name then
      sublist.id = group.id
      sublist.name = group.name
      sublist.priorty = group.priority
      sublist.hidden = group.hidden
      sublist.display_name = group.display_name
    end
    table.insert(sublist, buf)
    return accum
  end, buffers)
  tabs_by_group = sublists
  return utils.array_concat(unpack(sublists))
end

---Add group styling to the buffer component
---@param ctx RenderContext
---@return string
---@return number
function M.component(ctx)
  local buffer = ctx.tab:as_buffer()
  local hls = ctx.current_highlights
  local group = user_groups[buffer.group]
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

--- NOTE: this function mutates the user's configuration.
--- Add group highlights to the user highlights table
---@param config BufferlineConfig
function M.setup(config)
  assert(
    config and config.options,
    "A user configuration table must be passed in to set group highlights"
  )
  if not config.options.groups then
    return
  end

  local hls = config.highlights
  for idx, group in ipairs(config.options.groups) do
    local hl = group.highlight
    user_groups[idx] = vim.tbl_extend("force", group, {
      id = idx,
      hidden = false,
      name = format_name(group.name),
      priority = group.priority or idx,
      display_name = group.name,
    })
    local name = group.name
    if hl and type(hl) == "table" then
      hls[fmt("%s_selected", name)] = vim.tbl_extend("keep", hl, {
        guibg = hls.buffer_selected.guibg,
      })
      hls[fmt("%s_visible", name)] = vim.tbl_extend("keep", hl, {
        guibg = hls.buffer_visible.guibg,
      })
      hls[name] = vim.tbl_extend("keep", hl, {
        guibg = hls.buffer.guibg,
      })
    end
  end
  local no_of_groups = #config.options.groups
  user_groups[no_of_groups + 1] = {
    name = UNGROUPED,
    priority = no_of_groups + 1,
  }
end

--- Add the current highlight for a specific buffer
--- NOTE: this function mutates the current highlights.
---@param buffer Buffer
---@param highlights table<string, table<string, string>>
---@param current_hl table<string, string>
function M.set_current_hl(buffer, highlights, current_hl)
  local group = user_groups[buffer.group]
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
  local group = utils.find(tabs_by_group, function(list)
    return list.name == group_name
  end)
  utils.for_each(group, callback)
end

---@param name string
---@return Group
local function group_by_name(name)
  for _, grp in pairs(user_groups) do
    if grp.name == name then
      return grp
    end
  end
end

---@param group_id number
---@param name string
function M.toggle_hidden(group_id, name)
  local group = group_id and user_groups[group_id] or group_by_name(name)
  if group then
    group.hidden = not group.hidden
  end
end

---Get the names for all bufferline groups
---@param include_empty boolean
---@return string[]
function M.names(include_empty)
  if user_groups == nil then
    return {}
  end
  local names = {}
  for _, group in ipairs(user_groups) do
    local group_tabs = utils.find(tabs_by_group, function(item)
      return item.id == group.id
    end)
    if include_empty or (group_tabs and #group_tabs > 0) then
      table.insert(names, group.name)
    end
  end
  return names
end

---@param name string,
---@param group Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return string, number
function M.separator.pill(name, group, hls, count)
  local bg_hl = hls.fill.hl
  local sep_hl = hls.group_separator.hl
  local label_hl = hls.group_label.hl
  local left, right = "█", "█"
  local indicator = utils.join(
    bg_hl,
    padding,
    sep_hl,
    left,
    label_hl,
    name,
    count,
    sep_hl,
    right,
    padding
  )
  local length = utils.measure(left, right, name, count, padding, padding)
  return indicator, length
end

---@param name string,
---@param group Group,
---@param hls  table<string, table<string, string>>
---@param count string
---@return string, number
function M.separator.tab(name, group, hls, count)
  local hl = hls.fill.hl
  local indicator_hl = hls.buffer.hl
  local length = utils.measure(name, string.rep(padding, 4), count)
  local indicator = utils.join(hl, padding, indicator_hl, padding, name, count, hl, padding)
  return indicator, length
end

---Create the visual indicators bookending buffer groups
---@param name string
---@param group_id number
---@param tab_views TabView[]
---@return TabView
---@return TabView
local function get_tab(name, group_id, tab_views)
  local group = user_groups[group_id]
  if name == UNGROUPED or not group then
    return
  end
  local GroupView = require("bufferline.entities").GroupView
  local hl_groups = require("bufferline.config").get("highlights")

  group.separator = group.separator or {}
  --- NOTE: the default buffer group style is the pill
  group.separator.style = group.separator.style or M.separator.pill
  if not group.separator.style then
    return
  end
  local count_item = group.hidden and fmt("(%s)", #tab_views) or ""
  local indicator, length = group.separator.style(name, group, hl_groups, count_item)
  indicator = require("bufferline.utils").make_clickable("handle_group_click", group.id, indicator)

  local group_start = GroupView:new({
    type = "group_start",
    length = length,
    component = function()
      return indicator
    end,
  })
  local group_end = GroupView:new({
    type = "group_end",
    length = strwidth(padding),
    component = function()
      return utils.join(hl_groups.fill.hl, padding)
    end,
  })
  return group_start, group_end
end

-- FIXME:
-- 1. this function does a lot of looping that can maybe be consolidated
---@param tabs TabView[]
---@return TabView[]
---@return TabView[]
function M.add_markers(tabs)
  if vim.tbl_isempty(tabs_by_group) then
    return tabs
  end
  local result = {}
  for _, sublist in ipairs(tabs_by_group) do
    local buf_group_id = sublist.id
    local buf_group = user_groups[buf_group_id]
    --- filter out tab views that are hidden
    local tab_views = (not buf_group or not buf_group.hidden) and sublist
      or utils.map(function(t)
        t.hidden = true
        return t
      end, sublist)

    if sublist.name ~= UNGROUPED and #sublist > 0 then
      local group_start, group_end = get_tab(sublist.display_name, buf_group_id, sublist)
      if group_start then
        table.insert(tab_views, 1, group_start)
        tab_views[#tab_views + 1] = group_end
      end
    end
    --- NOTE: there is no easy way to flatten a list of liss of non-scalar values like these
    ---lists of objects since each object needs to be checked that it is in fact an object
    ---not a list
    vim.list_extend(result, tab_views)
  end
  return result
end

return M
