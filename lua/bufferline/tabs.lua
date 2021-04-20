local constants = require("bufferline/constants")

local M = {}

local strwidth = vim.fn.strwidth
local padding = constants.padding

local function tab_click_component(num)
  return "%" .. num .. "T"
end

local function render(tab, is_active, style, highlights)
  local h = highlights
  local hl = is_active and h.tab_selected.hl or h.tab.hl
  local separator_hl = is_active and h.separator_selected.hl or h.separator.hl
  local separator_component = style == "thick" and "▐" or "▕"
  local separator = separator_hl .. separator_component
  local name = padding .. padding .. tab.tabnr .. padding
  local length = strwidth(name) + strwidth(separator_component)
  return hl .. tab_click_component(tab.tabnr) .. name .. separator, length
end

--- @param style string
--- @param prefs table
function M.get(style, prefs)
  local all_tabs = {}
  local tabs = vim.fn.gettabinfo()
  local current_tab = vim.fn.tabpagenr()
  local highlights = prefs.highlights

  -- use contiguous numbers to ensure contiguous keys in the table i.e. an array
  -- rather than an object
  -- GOOD = {1: thing, 2: thing} BAD: {1: thing, [5]: thing}
  for i, tab in ipairs(tabs) do
    local is_active_tab = current_tab == tab.tabnr
    local component, length = render(tab, is_active_tab, style, highlights)

    all_tabs[i] = {
      component = component,
      length = length,
      id = tab.tabnr,
      windows = tab.windows,
    }
  end
  return all_tabs
end

return M
