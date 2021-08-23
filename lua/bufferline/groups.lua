local M = {}

local api = vim.api
local fmt = string.format

---@alias grouper fun(b: Buffer): boolean

---@class Group
---@field public name string
---@field public fn grouper
---@field public priority number
---@field public highlight string
---@field public icon string

---Group buffers based on user criteria
---@param buffer Buffer
---@param groups Group[]
function M.get(buffer, groups)
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
  local icon = group.icon and group.icon .. " " or ""
  local icon_length = api.nvim_strwidth(icon)
  local component, length = hls[group.name] .. icon .. ctx.component, ctx.length + icon_length
  return ctx:update({ component = component, length = length })
end

--- Add group highlights to the user highlights table
--- NOTE: this function mutates the user's configuration.
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
  local groups = config.options.groups
  for _, group in ipairs(groups) do
    local hl = group.highlight
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
---@param buffers Buffers[]
---@param group_name string
---@param callback fun(b: Buffer)
function M.command(buffers, group_name, callback)
  require("bufferline.utils").for_each(buffers, callback, function(buf)
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

return M
