local M = { separator = {} }
local api = vim.api

local fmt = string.format
local strwidth = api.nvim_strwidth
local utils = require("bufferline.utils")
local padding = require("bufferline.constants").padding

local UNGROUPED = "ungrouped"

---@alias GroupSeparator fun(name: string, group:Group, hls: tabl<string, table<string, string>>): string, number
---@alias GroupSeparators table<string, GroupSeparator>
---@alias grouper fun(b: Buffer): boolean

---@class Group
---@field public name string
---@field public fn grouper
---@field public separator GroupSeparators
---@field public priority number
---@field public highlight table<string, string>
---@field public icon string

---Group buffers based on user criteria
---@param buffer Buffer
---@param groups Group[]
function M.find(buffer, groups)
  if not groups or #groups < 1 then
    return
  end
  for index, group in ipairs(groups) do
    if type(group.fn) == "function" and group.fn(buffer) then
      group.priority = group.priority or index
      return group
    end
  end
end

---Save the current buffer groups
---@param buffers Buffer[]
function M.group_buffers(buffers)
  local res = utils.fold({}, function(accum, buf)
    local name = buf.group and buf.group.name or UNGROUPED
    accum[name] = accum[name] or {}
    table.insert(accum[name], buf)
    return accum
  end, buffers)
  return res, utils.array_concat(unpack(vim.tbl_values(res)))
end

---Add group styling to the buffer component
---@param ctx BufferContext
---@return string
---@return number
function M.component(ctx)
  local buffer = ctx.buffer
  local hls = ctx.current_highlights
  local group = buffer.group
  if not group then
    return ctx
  end
  --- TODO: should there be default icons at all
  local icon = group.icon and group.icon .. padding or ""
  local icon_length = api.nvim_strwidth(icon)
  local component, length = hls[group.name] .. icon .. ctx.component, ctx.length + icon_length
  return ctx:update({ component = component, length = length })
end

--- NOTE: this function mutates the user's configuration.
--- Add group highlights to the user highlights table
---@param config BufferlineConfig
function M.set_hls(config)
  assert(
    config and config.options,
    "A user configuration table must be passed in to set group highlights"
  )
  if not config.options.groups then
    return
  end
  local hls = config.highlights
  local _groups = config.options.groups
  for _, group in ipairs(_groups) do
    local hl = group.highlight
    local name = group.name
    hls[fmt("%s_selected", name)] = vim.tbl_extend("keep", hl, {
      guibg = hls.buffer_selected.guibg,
    })
    if hl and type(hl) == "table" then
      hls[fmt("%s_visible", name)] = vim.tbl_extend("keep", hl, {
        guibg = hls.buffer_visible.guibg,
      })
      hls[name] = vim.tbl_extend("keep", hl, {
        guibg = hls.buffer.guibg,
      })
    end
  end
end

--- Add the current highlight for a specific buffer
--- NOTE: this function mutates the current highlights.
---@param buffer Buffer
---@param highlights table<string, table<string, string>>
---@param current_hl table<string, string>
function M.set_current_hl(buffer, highlights, current_hl)
  local name = buffer.group and buffer.group.name or nil
  if not name then
    return
  end
  if buffer:current() then
    current_hl[name] = highlights[fmt("%s_selected", name)].hl
  elseif buffer:visible() then
    current_hl[name] = highlights[fmt("%s_visible", name)].hl
  else
    current_hl[name] = highlights[name].hl
  end
end

---Execute a command on each buffer of a group
---@param buffers Buffer[]
---@param group_name string
---@param callback fun(b: Buffer)
function M.command(buffers, group_name, callback)
  utils.for_each(buffers, callback, function(buf)
    return buf.group and group_name and buf.group.name == group_name
  end)
end

---Get the names for all bufferline groups
---@return string[]
function M.names()
  local opts = require("bufferline.config").get("options")
  if opts.groups == nil then
    return {}
  end
  return vim.tbl_map(function(group)
    return group.name
  end, opts.groups)
end

---@type GroupSeparator
function M.separator.pill(name, _, hls)
  local bg_hl = hls.fill.hl
  local sep_hl = hls.group_separator.hl
  local label_hl = hls.group_label.hl
  local left, right = "█", "█"
  local indicator = utils.join(bg_hl, padding, sep_hl, left, label_hl, name, sep_hl, right, padding)
  local length = utils.measure(left, right, name, padding, padding)
  return indicator, length
end

---@type GroupSeparator
function M.separator.tab(name, _, hls)
  local hl = hls.fill.hl
  local indicator_hl = hls.buffer.hl
  local length = strwidth(name) + (4 * strwidth(padding))
  local indicator = utils.join(hl, padding, indicator_hl, padding, name, padding, hl, padding)
  return indicator, length
end

---Create the visual indicators bookending buffer groups
---@param name string
---@param group Group
---@return ViewTab
---@return ViewTab
local function get_tab(name, group)
  if name == UNGROUPED or not group then
    return
  end
  local ViewTab = require("bufferline.view").ViewTab
  local hl_groups = require("bufferline.config").get("highlights")

  group.separator = group.separator or {}
  --- NOTE: the default buffer group style is the pill
  group.separator.style = group.separator.style or M.separator.pill
  if not group.separator.style then
    return
  end
  local indicator, length = group.separator.style(name, group, hl_groups)

  local group_start = ViewTab:new({
    length = length,
    component = function()
      return indicator
    end,
  })
  local group_end = ViewTab:new({
    length = strwidth(padding),
    component = function()
      return utils.join(hl_groups.fill.hl, padding)
    end,
  })
  return group_start, group_end
end

---@param buffers Buffer[]
---@param groups table<string, Buffer[]>
---@return ViewTab[]
function M.add_markers(buffers, groups)
  if vim.tbl_isempty(groups) then
    return buffers
  end
  local res = {}
  for name, grp_buffers in pairs(groups) do
    local list = grp_buffers
    if name ~= UNGROUPED and #grp_buffers > 0 then
      local group_start, group_end = get_tab(name, grp_buffers[1].group)
      if group_start then
        table.insert(list, 1, group_start)
        table.insert(list, group_end)
      end
    end
    vim.list_extend(res, list)
  end
  return res
end

return M
