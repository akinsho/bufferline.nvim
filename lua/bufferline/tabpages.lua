local lazy = require("bufferline.lazy")
-- @module "bufferline.ui"
local ui = lazy.require("bufferline.ui")
-- @module "bufferline.pick"
local pick = lazy.require("bufferline.pick")
-- @module "bufferline.config"
local config = lazy.require("bufferline.config")
-- @module "bufferline.constants"
local constants = lazy.require("bufferline.constants")
-- @module "bufferline.diagnostics"
local diagnostics = lazy.require("bufferline.diagnostics")

local api = vim.api

local M = {}

local strwidth = vim.fn.strwidth
local padding = constants.padding

local function tab_click_component(num)
  return "%" .. num .. "T"
end

local function render(tabpage, is_active, style, highlights)
  local h = highlights
  local hl = is_active and h.tab_selected.hl or h.tab.hl
  local separator_hl = is_active and h.separator_selected.hl or h.separator.hl
  local separator_component = style == "thick" and "▐" or "▕"
  local separator = separator_hl .. separator_component
  local name = padding .. padding .. tabpage.tabnr .. padding
  local length = strwidth(name) + strwidth(separator_component)
  return hl .. tab_click_component(tabpage.tabnr) .. name .. separator, length
end

function M.get()
  local tabpages = {}
  local tabs = vim.fn.gettabinfo()
  local current_tab = vim.fn.tabpagenr()
  local highlights = config.highlights
  local style = config.options.separator_style
  for i, tab in ipairs(tabs) do
    local is_active_tab = current_tab == tab.tabnr
    local component, length = render(tab, is_active_tab, style, highlights)

    tabpages[i] = {
      component = component,
      length = length,
      id = tab.tabnr,
      windows = tab.windows,
    }
  end
  return tabpages
end

---Choose the active window's buffer as the buffer for that tab
---@param tab_num integer
---@return string
---@return number
local function get_tab_buffer_details(tab_num)
  local window = api.nvim_tabpage_get_win(tab_num)
  local buf = api.nvim_win_get_buf(window)
  local name = (buf and api.nvim_buf_is_valid(buf)) and api.nvim_buf_get_name(buf) or "[No name]"
  return name, buf
end

local function get_valid_tabs()
  return vim.tbl_filter(function(t)
    return api.nvim_tabpage_is_valid(t)
  end, api.nvim_list_tabpages())
end

--- Get tab buffers based on open windows within the tab
--- this is similar to tabpagebuflist but doesn't involve
--- the viml round trip or the quirk where it occasionally returns
--- a number
---@param tab_num number
---@return number[]
local function get_tab_buffers(tab_num)
  return vim.tbl_map(api.nvim_win_get_buf, api.nvim_tabpage_list_wins(tab_num))
end

---@param state BufferlineState
---@return Tabpage[]
function M.get_components(state)
  local options = config.options
  local tabs = get_valid_tabs()

  local Tabpage = require("bufferline.models").Tabpage
  ---@type Tabpage[]
  local components = {}
  pick.reset()

  for i, tab_num in ipairs(tabs) do
    local buffers = get_tab_buffers(tab_num)
    local path, buf_num = get_tab_buffer_details(tab_num)
    local all_diagnostics = diagnostics.get(options)
    -- TODO: decide how diagnostics should render if the focused
    -- window doesn't have any errors but a neighbouring window does
    -- local match = utils.find(buffers, function(item)
    --   return all_diagnostics[item].count > 0
    -- end)
    local tab = Tabpage:new({
      path = path,
      buf = buf_num,
      buffers = buffers,
      id = tab_num,
      ordinal = i,
      diagnostics = all_diagnostics[buf_num],
      name_formatter = options.name_formatter,
      hidden = false,
      focusable = true,
    })
    tab.letter = pick.get(tab)
    components[#components + 1] = tab
  end
  return vim.tbl_map(function(tab)
    return ui.element(state, tab)
  end, components)
end

return M
