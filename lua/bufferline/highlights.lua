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

local api = vim.api
local v = constants.visibility
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

local PREFIX = "BufferLine"

local visibility_suffix = {
  [v.INACTIVE] = "Inactive",
  [v.SELECTED] = "Selected",
  [v.NONE] = "",
}

--- @class NameGenerationArgs
--- @field visibility number

--- Create a highlight name from a string using the bufferline prefix as well as appending the state
--- of the element
---@param name string
---@param opts NameGenerationArgs
---@return string
function M.generate_name(name, opts)
  opts = opts or {}
  return fmt("%s%s%s", PREFIX, name, visibility_suffix[opts.visibility])
end

function M.hl(item)
  if not item then return "" end
  return "%#" .. item .. "#"
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

local keys = {
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
  keys.ctermfg = "ctermfg"
  keys.ctermbg = "ctermbg"
  keys.cterm = "cterm"
end

--- Transform legacy highlight keys to new nvim_set_hl api keys
---@param opts table<string, string>
---@return table<string, string|boolean>
function M.translate_legacy_options(opts)
  assert(opts, '"opts" must be passed for conversion')
  local hls = {}
  for key, value in pairs(opts) do
    if keys[key] then hls[keys[key]] = value end
  end
  if opts.gui then hls = vim.tbl_extend("force", hls, convert_gui(opts.gui)) end
  hls.default = opts.default or (config.options and config.options.themable)
  return hls
end

local function filter_invalid_keys(hl)
  return utils.fold(function(accum, item, key)
    if keys[key] then accum[key] = item end
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
        fmt("Failed setting %s  highlight, something isn't configured correctly: %s", name, msg),
        utils.E
      )
    end
  end
end

---Generate highlight groups from user
---@param highlight table
function M.add_group(name, highlight)
  -- convert 'bufferline_value' to 'BufferlineValue' -> snake to pascal
  local formatted = PREFIX .. name:gsub("_(.)", name.upper):gsub("^%l", string.upper)
  highlight.hl = formatted
end

--- Map through user colors and convert the keys to highlight names
--- by changing the strings to pascal case and using those for highlight name
--- @param conf BufferlineConfig
function M.set_all(conf)
  for name, tbl in pairs(conf.highlights) do
    if not tbl or not tbl.hl then
      local msg = fmt("Error setting highlight group: no name for %s - %s", name, vim.inspect(tbl))
      utils.notify(msg, utils.E)
    else
      M.set_one(tbl.hl, tbl)
    end
  end
end

---@param vis 1|2|3
---@return string
local function get_name_by_state(vis, name, base)
  if not base then base = name end
  local s = { [v.INACTIVE] = "%s_visible", [v.SELECTED] = "%s_selected" }
  return s[vis] and fmt(s[vis], name) or base
end

--- Add the current highlight for a specific element
--- NOTE: this function mutates the current highlights.
---@param element TabElement
---@param hls table<string, table<string, string>>
---@param current_hl table<string, string>
local function add_element_group_hl(element, hls, current_hl)
  if not element.group then return end
  local group = groups.get_all()[element.group]
  if not group or not group.name or not group.highlight then return end
  local name = group.name
  local hl_name = get_name_by_state(element:visibility(), name)
  if not hls[hl_name] then return utils.log.debug(fmt("%s group highlight not found", name)) end
  current_hl[name] = hls[hl_name].hl
end

---@param element NvimBuffer | NvimTab
---@return table
function M.for_element(element)
  local hl = {}
  local h = config.highlights
  if not h then return hl end
  local vis = element:visibility()

  ---@param name string
  ---@param base string?
  ---@return BufferlineHLGroup
  local function current_state(name, base) return h[get_name_by_state(vis, name, base)] or {} end

  hl.modified = current_state("modified").hl
  hl.duplicate = current_state("duplicate").hl
  hl.pick = current_state("pick").hl
  hl.separator = current_state("separator").hl
  hl.diagnostic = current_state("diagnostic").hl
  hl.error = current_state("error").hl
  hl.error_diagnostic = current_state("error_diagnostic").hl
  hl.warning = current_state("warning").hl
  hl.warning_diagnostic = current_state("warning_diagnostic").hl
  hl.info = current_state("info").hl
  hl.info_diagnostic = current_state("info_diagnostic").hl
  hl.hint = current_state("hint").hl
  hl.hint_diagnostic = current_state("hint_diagnostic").hl
  hl.close_button = current_state("close_button").hl
  hl.numbers = current_state("numbers").hl
  hl.buffer = current_state("buffer", "background")
  hl.background = hl.buffer.hl

  add_element_group_hl(element, h, hl)
  return hl
end

return M
