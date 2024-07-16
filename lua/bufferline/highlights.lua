local fmt = string.format
local lazy = require("bufferline.lazy")
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local constants = lazy.require("bufferline.constants") ---@module "bufferline.constants"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"
local groups = lazy.require("bufferline.groups") ---@module "bufferline.groups"
local colors = require("bufferline.colors") ---@module "bufferline.colors"
local log = lazy.require("bufferline.utils.log") ---@module "bufferline.utils.log"

local api = vim.api
local visibility = constants.visibility
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

local PREFIX = "BufferLine"

--- Generate highlight groups names i.e
--- convert 'bufferline_value' to 'BufferlineValue' -> snake to pascal
---@param name string
function M.generate_name(name) return PREFIX .. name:gsub("_(.)", name.upper):gsub("^%l", string.upper) end

--- Wrap a string in vim's tabline highlight syntax
---@param item string
---@return string
function M.hl(item)
  if not item then return "" end
  return fmt("%%#%s#", item)
end

local hl_keys = {
  fg = true,
  bg = true,
  sp = true,
  default = true,
  link = true,
  italic = true,
  bold = true,
  underline = true,
  undercurl = true,
  underdot = true,
}

---These values will error if a theme does not set a normal ctermfg or ctermbg @see: #433
if not vim.opt.termguicolors:get() then
  hl_keys.ctermfg = "ctermfg"
  hl_keys.ctermbg = "ctermbg"
  hl_keys.cterm = "cterm"
end

local function filter_invalid_keys(hl)
  return utils.fold(function(accum, item, key)
    if hl_keys[key] then accum[key] = item end
    return accum
  end, hl)
end

---Apply a single highlight
---@param name string
---@param opts {[string]: string | boolean}
---@return {[string]: string | boolean}?
function M.set(name, opts)
  if not opts or vim.tbl_isempty(opts) then return end
  local hl = filter_invalid_keys(opts)
  hl.default = vim.F.if_nil(opts.default, config.options.themable)
  local ok, msg = pcall(api.nvim_set_hl, 0, name, hl)
  if ok then return hl end
  utils.notify(fmt("Failed setting %s highlight, something isn't configured correctly: %s", name, msg), "error")
end

--- @param conf bufferline.Config
function M.set_all(conf)
  local msgs = {}
  for name, opts in pairs(conf.highlights) do
    if not opts or not opts.hl_group then
      msgs[#msgs + 1] = fmt("* %s - %s", name, vim.inspect(opts))
    else
      M.set(opts.hl_group, opts)
    end
  end
  if next(msgs) then
    utils.notify(fmt("Error setting highlight group(s) for: \n", table.concat(msgs, "\n")), "error")
  end
end

local icon_hl_cache = {}

function M.reset_icon_hl_cache() icon_hl_cache = {} end

--- Generate and set a highlight for an element's icon
--- this value is cached until the colorscheme changes to prevent
--- redundant calls to set the same highlight constantly
---@param state bufferline.Visibility
---@param hls bufferline.Highlights
---@param base_hl string
---@return string
function M.set_icon_highlight(state, hls, base_hl)
  local state_props = ({
    [visibility.INACTIVE] = { "Inactive", hls.buffer_visible },
    [visibility.SELECTED] = { "Selected", hls.buffer_selected },
    [visibility.NONE] = { "", hls.background },
  })[state]
  local icon_hl, parent = PREFIX .. base_hl .. state_props[1], state_props[2]
  if icon_hl_cache[icon_hl] then return icon_hl end

  local color_icons = config.options.color_icons
  local color = not color_icons and "NONE"
  local hl_colors = vim.tbl_extend("force", parent, {
    fg = color or colors.get_color({ name = base_hl, attribute = "fg" }),
    ctermfg = color or colors.get_color({ name = base_hl, attribute = "fg", cterm = true }),
    italic = false,
    bold = false,
    hl_group = icon_hl,
  })
  M.set(icon_hl, hl_colors)
  icon_hl_cache[icon_hl] = true
  return icon_hl
end

---@param vis bufferline.Visibility
---@param hls bufferline.Highlights
---@param name string
---@param base string?
---@return string
local function get_hl_group_for_state(vis, hls, name, base)
  if not base then base = name end
  local state = ({ [visibility.INACTIVE] = "visible", [visibility.SELECTED] = "selected" })[vis]
  local hl_name = state and fmt("%s_%s", name, state) or base
  if hls[hl_name].hl_group then return hls[hl_name].hl_group end
  log.debug(fmt("%s highlight not found", name))
  return ""
end

--- Return the correct highlight groups for each element i.e.
--- if the element is selected, visible or inactive it's highlights should differ
---@param element bufferline.Buffer | bufferline.Tab
---@return table<string, string>
function M.for_element(element)
  local hl = {}

  ---@param name string
  ---@param fallback string?
  local function hl_group(name, fallback)
    return get_hl_group_for_state(element:visibility(), config.highlights, name, fallback)
  end

  hl.modified = hl_group("modified")
  hl.duplicate = hl_group("duplicate")
  hl.pick = hl_group("pick")
  hl.separator = hl_group("separator")
  hl.diagnostic = hl_group("diagnostic")
  hl.error = hl_group("error")
  hl.error_diagnostic = hl_group("error_diagnostic")
  hl.warning = hl_group("warning")
  hl.warning_diagnostic = hl_group("warning_diagnostic")
  hl.info = hl_group("info")
  hl.info_diagnostic = hl_group("info_diagnostic")
  hl.hint = hl_group("hint")
  hl.hint_diagnostic = hl_group("hint_diagnostic")
  hl.close_button = hl_group("close_button")
  hl.numbers = hl_group("numbers")
  hl.buffer = hl_group("buffer", "background")
  hl.background = hl.buffer

  -- If the element is part of a group then the highlighting for the elements name will be changed
  -- to match highlights for that group
  if element.group then
    local group = groups.get_all()[element.group]
    if group and group.name and group.highlight then hl.buffer = hl_group(group.name) end
  end
  return hl
end

return M
