local fmt = string.format
local lazy = require("bufferline.lazy")
--- @module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
--- @module "bufferline.constants"
local constants = lazy.require("bufferline.constants")
--- @module "bufferline.config"
local config = lazy.require("bufferline.config")
--- @module "bufferline.groups"
local groups = lazy.require("bufferline.groups")
--- @module "bufferline.utils.log"
local log = lazy.require("bufferline.utils.log")

local api = vim.api
local V = constants.visibility
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

local PREFIX = "BufferLine"

--- @class NameGenerationArgs
--- @field visibility number

--- Create a highlight name from a string using the bufferline prefix as well as appending the state
--- of the element
---@param name string
---@param opts NameGenerationArgs
---@return string
function M.generate_name_for_state(name, opts)
  opts = opts or {}
  local visibility_suffix = ({
    [V.INACTIVE] = "Inactive",
    [V.SELECTED] = "Selected",
    [V.NONE] = "",
  })[opts.visibility]
  return fmt("%s%s%s", PREFIX, name, visibility_suffix)
end

--- Generate highlight groups names i.e
--- convert 'bufferline_value' to 'BufferlineValue' -> snake to pascal
---@param name string
function M.generate_name(name)
  return PREFIX .. name:gsub("_(.)", name.upper):gsub("^%l", string.upper)
end

--- Wrap a string in vim's tabline highlight syntax
---@param item string
---@return string
function M.hl(item)
  if not item then return "" end
  return fmt("%%#%s#", item)
end

function M.hl_exists(name) return vim.fn.hlexists(name) > 0 end

local function convert_gui(guistr)
  local gui = {}
  if guistr:lower():match("none") then return gui end
  local parts = vim.split(guistr, ",")
  for _, part in ipairs(parts) do
    gui[part] = true
  end
  return gui
end

local hl_keys = {
  guisp = "sp",
  guibg = "bg",
  guifg = "fg",
  default = "default",
  foreground = "fg",
  background = "fg",
  fg = "fg",
  bg = "bg",
  sp = "special",
  italic = "italic",
  bold = "bold",
  underline = "underline",
  undercurl = "undercurl",
  underdot = "underdot",
}

---These values will error if a theme does not set a normal ctermfg or ctermbg @see: #433
if not vim.opt.termguicolors:get() then
  hl_keys.ctermfg = "ctermfg"
  hl_keys.ctermbg = "ctermbg"
  hl_keys.cterm = "cterm"
end

--- Transform user highlight keys to the correct subset of nvim_set_hl API arguments
---@param opts table<string, string>
---@return table<string, string|boolean>
function M.translate_user_highlights(opts)
  assert(opts, '"opts" must be passed for conversion')
  local attributes = {}
  for attr, value in pairs(opts) do
    if hl_keys[attr] then attributes[hl_keys[attr]] = value end
  end
  if opts.gui then attributes = vim.tbl_extend("force", attributes, convert_gui(opts.gui)) end
  attributes.default = vim.F.if_nil(opts.default, config.options.themable)
  return attributes
end

local function filter_invalid_keys(hl)
  return utils.fold(function(accum, item, key)
    if hl_keys[key] then accum[key] = item end
    return accum
  end, hl)
end

---Apply a single highlight
---@param name string
---@param opts table<string, string>
function M.set_one(name, opts)
  if opts and not vim.tbl_isempty(opts) then
    local hl = filter_invalid_keys(opts)
    local ok, msg = pcall(api.nvim_set_hl, 0, name, hl)
    if not ok then
      utils.notify(
        fmt("Failed setting %s highlight, something isn't configured correctly: %s", name, msg),
        "error"
      )
    end
  end
end

--- Map through user colors and convert the keys to highlight names
--- by changing the strings to pascal case and using those for highlight name
--- @param conf BufferlineConfig
function M.set_all(conf)
  local msgs = {}
  for name, opts in pairs(conf.highlights) do
    if not opts or not opts.hl_group then
      msgs[#msgs + 1] = fmt("* %s - %s", name, vim.inspect(opts))
    else
      M.set_one(opts.hl_group, opts)
    end
  end
  if next(msgs) then
    utils.notify(fmt("Error setting highlight group(s) for: \n", table.concat(msgs, "\n")), "error")
  end
end

---@param vis Visibility
---@param hls BufferlineHighlights
---@param name string
---@param base string?
---@return string
local function get_hl_group_for_state(vis, hls, name, base)
  if not base then base = name end
  local state = ({ [V.INACTIVE] = "visible", [V.SELECTED] = "selected" })[vis]
  local hl_name = state and fmt("%s_%s", name, state) or base
  if hls[hl_name].hl_group then return hls[hl_name].hl_group end
  log.debug(fmt("%s highlight not found", name))
  return ""
end

---@param element NvimBuffer | NvimTab
---@return table<string, string>
function M.for_element(element)
  local hl = {}

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

  if element.group then
    local group = groups.get_all()[element.group]
    if group and group.name and group.highlight then hl[group.name] = hl_group(group.name) end
  end
  return hl
end

return M
