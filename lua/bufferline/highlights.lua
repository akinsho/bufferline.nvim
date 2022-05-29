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
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

local PREFIX = "BufferLine"

local visibility_suffix = {
  [constants.visibility.INACTIVE] = "Inactive",
  [constants.visibility.SELECTED] = "Selected",
  [constants.visibility.NONE] = "",
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
  if not item then
    return ""
  end
  return "%#" .. item .. "#"
end

function M.hl_exists(name)
  return vim.fn.hlexists(name) > 0
end

local function convert_gui(guistr)
  local gui = {}
  if guistr:lower():match("none") then
    return gui
  end
  local parts = vim.split(guistr, ",")
  for _, part in ipairs(parts) do
    gui[part] = true
  end
  return gui
end

local keys = {
  guisp = "sp",
  guibg = "background",
  guifg = "foreground",
  default = "default",
  ctermfg = "ctermfg",
  ctermbg = "ctermbg",
  cterm = "cterm",
  foreground = "foreground",
  background = "background",
  italic = "italic",
  bold = "bold",
  underline = "underline",
  undercurl = "undercurl",
  underdot = "underdot",
}

--- Transform legacy highlight keys to new nvim_set_hl api keys
---@param opts table<string, string>
---@return table<string, string|boolean>
local function convert_hl_keys(opts)
  local hls = {}
  for key, value in pairs(opts) do
    if keys[key] then
      hls[keys[key]] = value
    end
  end
  if opts.gui then
    hls = vim.tbl_extend("force", hls, convert_gui(opts.gui))
  end
  hls.default = vim.F.if_nil(opts.default, config.options.themable)
  return hls
end

---Apply a single highlight
---@param name string
---@param opts table<string, string>
function M.set_one(name, opts)
  if opts and not vim.tbl_isempty(opts) then
    local hls = convert_hl_keys(opts)
    local ok, msg = pcall(api.nvim_set_hl, 0, name, hls)
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
      utils.notify(
        fmt("Error setting highlight group: no name for %s - %s", name, vim.inspect(tbl), utils.E)
      )
    else
      M.set_one(tbl.hl, tbl)
    end
  end
end

---@param element Buffer | Tabpage
---@return table
function M.for_element(element)
  local hl = {}
  local h = config.get("highlights")
  --- TODO: find a tidier way to do this if possible
  if element:current() then
    hl.background = h.buffer_selected.hl
    hl.modified = h.modified_selected.hl
    hl.duplicate = h.duplicate_selected.hl
    hl.pick = h.pick_selected.hl
    hl.separator = h.separator_selected.hl
    hl.buffer = h.buffer_selected
    hl.diagnostic = h.diagnostic_selected.hl
    hl.error = h.error_selected.hl
    hl.error_diagnostic = h.error_diagnostic_selected.hl
    hl.warning = h.warning_selected.hl
    hl.warning_diagnostic = h.warning_diagnostic_selected.hl
    hl.info = h.info_selected.hl
    hl.info_diagnostic = h.info_diagnostic_selected.hl
    hl.hint = h.hint_selected.hl
    hl.hint_diagnostic = h.hint_diagnostic_selected.hl
    hl.close_button = h.close_button_selected.hl
    hl.numbers = h.numbers_selected.hl
  elseif element:visible() then
    hl.background = h.buffer_visible.hl
    hl.modified = h.modified_visible.hl
    hl.duplicate = h.duplicate_visible.hl
    hl.pick = h.pick_visible.hl
    hl.separator = h.separator_visible.hl
    hl.buffer = h.buffer_visible
    hl.diagnostic = h.diagnostic_visible.hl
    hl.error = h.error_visible.hl
    hl.error_diagnostic = h.error_diagnostic_visible.hl
    hl.warning = h.warning_visible.hl
    hl.warning_diagnostic = h.warning_diagnostic_visible.hl
    hl.info = h.info_visible.hl
    hl.info_diagnostic = h.info_diagnostic_visible.hl
    hl.hint = h.hint_visible.hl
    hl.hint_diagnostic = h.hint_diagnostic_visible.hl
    hl.close_button = h.close_button_visible.hl
    hl.numbers = h.numbers_visible.hl
  else
    hl.background = h.background.hl
    hl.modified = h.modified.hl
    hl.duplicate = h.duplicate.hl
    hl.pick = h.pick.hl
    hl.separator = h.separator.hl
    hl.buffer = h.background
    hl.diagnostic = h.diagnostic.hl
    hl.error = h.error.hl
    hl.error_diagnostic = h.error_diagnostic.hl
    hl.warning = h.warning.hl
    hl.warning_diagnostic = h.warning_diagnostic.hl
    hl.info = h.info.hl
    hl.info_diagnostic = h.info_diagnostic.hl
    hl.hint = h.hint.hl
    hl.hint_diagnostic = h.hint_diagnostic.hl
    hl.close_button = h.close_button.hl
    hl.numbers = h.numbers.hl
  end

  if element.group then
    groups.set_current_hl(element, h, hl)
  end

  return hl
end

return M
