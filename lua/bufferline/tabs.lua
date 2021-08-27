local constants = require("bufferline/constants")

local M = {}

local strwidth = vim.fn.strwidth
local padding = constants.padding

local function tab_click_component(num)
  return "%" .. num .. "T"
end

local function render(tab, is_active, style, highlights, tab_indicator_style)
  local h = highlights
  local hl = is_active and h.tab_selected.hl or h.tab.hl
  local separator_hl = is_active and h.separator_selected.hl or h.separator.hl
  local separator_component = style == "thick" and "▐" or "▕"
  local separator = separator_hl .. separator_component
  local bufname

  if type(tab_indicator_style) == "function" then
  -- we have tab.mru_buf and tab.name which is the mru_buf's name for convenience
    bufname = tab_indicator_style(tab)
  else
    if tab_indicator_style == "tabnr" then
      bufname = tab.tabnr
    elseif tab.name and tab.name ~= "" then
      bufname = tab.name:match("^.+/(.+)$")
    else
      bufname = "[No Name]"
    end
    if tab_indicator_style == "both" then
      bufname = tab.tabnr .. ': ' .. bufname
    end
  end

  local name = padding .. padding .. bufname .. padding
  local length = strwidth(name) + strwidth(separator_component)
  return hl .. tab_click_component(tab.tabnr) .. name .. separator, length
end

-- @param tab table
local function get_mru_buffer(tab)
  local mru_buffer = vim.api.nvim_win_get_buf(tab.windows[1])
  local mru_timestamp = vim.fn.getbufinfo(mru_buffer)[1].lastused
  local buf
  local timestamp
  for _, w in ipairs(tab.windows) do
    buf = vim.api.nvim_win_get_buf(w)
    timestamp = vim.fn.getbufinfo(buf)[1].lastused
    if timestamp > mru_timestamp then
      mru_buffer = buf
      mru_timestamp = timestamp
    end
  end
  return mru_buffer
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
  -- GOOD: = {1: thing, 2: thing} BAD: {1: thing, [5]: thing}
  for i, tab in ipairs(tabs) do
    local is_active_tab = current_tab == tab.tabnr
    local buf = get_mru_buffer(tab)
    tab.name = vim.api.nvim_buf_get_name(buf)
    tab.mru_buf = buf
    local component, length = render(tab, is_active_tab, style, highlights, prefs.options.tab_indicator_style)
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
