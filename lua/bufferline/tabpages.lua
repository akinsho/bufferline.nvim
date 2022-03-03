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
  local highlights = config.get("highlights")
  local style = config.get("options").separator_style

  -- use contiguous numbers to ensure contiguous keys in the table i.e. an array
  -- rather than an object
  -- GOOD = {1: thing, 2: thing} BAD: {1: thing, [5]: thing}
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

local function get_tab_name(tab_num)
  local no_name
  if not api.nvim_tabpage_is_valid(tab_num) then
    return "[No name]"
  end
  local buflist = fn.tabpagebuflist(tab_num)
  -- tabpagebuflist can return 0 if the tab page number was invalid
  -- if this happens show no name
  if buflist == 0 or #buflist < 1 then
    return no_name
  end
  local winnr = fn.tabpagewinnr(tab_num)
  return fn.bufname(buflist[winnr]), buflist[winnr]
end

---@param state BufferlineState
---@return Tabpage[]
function M.get_components(state)
  local options = config.get("options")
  local tabs = api.nvim_list_tabpages()
  local Tabpage = require("bufferline.models").Tabpage
  ---@type Tabpage[]
  local components = {}
  for i, tab_num in ipairs(tabs) do
    local path, buf_num = get_tab_name(tab_num)
    components[i] = Tabpage:new({
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
  return vim.tbl_map(function(tab)
    return ui.element(state, tab)
  end, components)
end

return M
