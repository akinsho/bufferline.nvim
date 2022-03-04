local ui = require("bufferline.ui")
local config = require("bufferline.config")
local constants = require("bufferline.constants")

local fn = vim.fn
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
local function get_tab_buffer_details(tab_num, buffers)
  -- tabpagebuflist can return 0 if the tab page number was invalid
  -- if this happens show no name
  local winnr = fn.tabpagewinnr(tab_num)
  local name = fn.bufname(buffers[winnr])
  name = name ~= "" and name or "[No name]"
  return name, buffers[winnr]
end

local function get_valid_tabs()
  return vim.tbl_filter(function(t)
    return api.nvim_tabpage_is_valid(t)
  end, api.nvim_list_tabpages())
end

---@param state BufferlineState
---@return Tabpage[]
function M.get_components(state)
  local options = config.options
  local tabs = get_valid_tabs()

  local Tabpage = require("bufferline.models").Tabpage
  ---@type Tabpage[]
  local components = {}
  for i, tab_num in ipairs(tabs) do
    local buffers = fn.tabpagebuflist(tab_num)
    -- tabpagebuflist can return 0 if the tab page number was invalid in this case
    -- skip this tab as it won't have any associated buffers
    if type(buffers) == "table" then
      local path, buf_num = get_tab_buffer_details(tab_num, buffers)
      if buf_num then
        components[#components + 1] = Tabpage:new({
          path = path,
          buf = buf_num,
          id = tab_num,
          ordinal = i,
          diagnostics = {},
          name_formatter = options.name_formatter,
          hidden = false,
          focusable = true,
        })
      end
    end
  end
  return vim.tbl_map(function(tab)
    return ui.element(state, tab)
  end, components)
end

return M
