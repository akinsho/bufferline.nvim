local lazy = require("bufferline.lazy")
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local pick = lazy.require("bufferline.pick") ---@module "bufferline.pick"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"
local constants = lazy.require("bufferline.constants") ---@module "bufferline.constants"
local duplicates = lazy.require("bufferline.duplicates") ---@module "bufferline.duplicates"
local diagnostics = lazy.require("bufferline.diagnostics") ---@module "bufferline.diagnostics"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local models = lazy.require("bufferline.models") ---@module "bufferline.models"

local api = vim.api

local M = {}

local padding = constants.padding

local function tab_click_component(num) return "%" .. num .. "T" end

---@param tabpage { tabnr: number, variables: { name: string }, windows: number[] }
---@param is_active boolean
---@param style string | { [1]: string, [2]: string }
---@param highlights bufferline.Highlights
local function render(tabpage, is_active, style, highlights)
  local h = highlights
  local hl = is_active and h.tab_selected.hl_group or h.tab.hl_group
  local separator_hl = is_active and h.tab_separator_selected.hl_group or h.tab_separator.hl_group
  local chars = type(style) == "table" and style or constants.sep_chars[style] or constants.sep_chars.thin
  local name = padding .. (tabpage.variables.name or tabpage.tabnr) .. padding
  local char_order = ({ thick = { 1, 2 }, thin = { 1, 2 } })[style] or { 2, 1 }
  return {
    { highlight = separator_hl, text = chars[char_order[1]] },
    {
      highlight = hl,
      text = name,
      attr = { prefix = tab_click_component(tabpage.tabnr) },
    },
    { highlight = separator_hl, text = chars[char_order[2]] },
  }
end

function M.rename_tab(tabnr, name)
  if name == "" then name = tostring(tabnr) end
  api.nvim_tabpage_set_var(0, "name", name)
  ui.refresh()
end

function M.get()
  local tabs = vim.fn.gettabinfo()
  local current_tab = vim.fn.tabpagenr()
  local highlights = config.highlights
  local style = config.options.separator_style
  return utils.map(function(tab)
    local is_active_tab = current_tab == tab.tabnr
    local components = render(tab, is_active_tab, style, highlights)
    return {
      component = components,
      id = tab.tabnr,
      windows = tab.windows,
    }
  end, tabs)
end

---@param tab_num integer
---@return integer
local function get_active_buf_for_tab(tab_num)
  local window = api.nvim_tabpage_get_win(tab_num)
  return api.nvim_win_get_buf(window)
end

---Choose the active window's buffer as the buffer for that tab
---@param buf integer
---@return string
local function get_buffer_name(buf)
  local name = (buf and api.nvim_buf_is_valid(buf)) and api.nvim_buf_get_name(buf)
  if not name or name == "" then name = "[No Name]" end
  return name
end

local function get_valid_tabs()
  return vim.tbl_filter(function(t) return api.nvim_tabpage_is_valid(t) end, api.nvim_list_tabpages())
end

---Filter the buffers to show based on the user callback passed in
---@param buf_nums integer[]
---@param callback fun(buf: integer, bufs: integer[]): boolean
---@return integer[]
local function apply_buffer_filter(buf_nums, callback)
  if type(callback) ~= "function" then return buf_nums end
  local filtered = {}
  for _, buf in ipairs(buf_nums) do
    if callback(buf, buf_nums) then table.insert(filtered, buf) end
  end
  return next(filtered) and filtered or buf_nums
end

--- Get tab buffers based on open windows within the tab
--- this is similar to tabpagebuflist but doesn't involve
--- the viml round trip or the quirk where it occasionally returns
--- a number
---@param tab_num number
---@return number[]
local function get_tab_buffers(tab_num) return vim.tbl_map(api.nvim_win_get_buf, api.nvim_tabpage_list_wins(tab_num)) end

local function get_diagnostics(buffers, options)
  local all_diagnostics = diagnostics.get(options)
  local buffer_diagnostics = {}
  local included_paths = {}
  for buffer, item in pairs(all_diagnostics) do
    local path = get_buffer_name(buffer)
    if vim.tbl_contains(buffers, buffer) and not vim.tbl_contains(included_paths, path) then
      table.insert(included_paths, path)
      table.insert(buffer_diagnostics, item)
    end
  end
  return diagnostics.combine(buffer_diagnostics)
end

---@param state bufferline.State
---@return bufferline.Tab[]
function M.get_components(state)
  local options = config.options
  local tabs = get_valid_tabs()

  local Tabpage = models.Tabpage
  ---@type bufferline.Tab[]
  local components = {}
  pick.reset()
  duplicates.reset()

  local filter = options.custom_filter

  for i, tab_num in ipairs(tabs) do
    local active_buf = get_active_buf_for_tab(tab_num)
    local buffers = get_tab_buffers(tab_num)
    local buffer
    if filter then
      buffers = apply_buffer_filter(buffers, filter)
      buffer = filter(active_buf) and active_buf or buffers[1]
    else
      buffer = active_buf
    end
    local path = get_buffer_name(buffer)
    local tab = Tabpage:new({
      path = path,
      buf = buffer,
      buffers = buffers,
      id = tab_num,
      ordinal = i,
      diagnostics = get_diagnostics(buffers, options),
      name_formatter = options.name_formatter,
      hidden = false,
      focusable = true,
    })
    tab.letter = pick.get(tab)
    components[#components + 1] = tab
  end
  return vim.tbl_map(function(tab) return ui.element(state, tab) end, duplicates.mark(components))
end

return M
