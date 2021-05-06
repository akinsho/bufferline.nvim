local M = {}

local api = vim.api
local fn = vim.fn

local t = {
  LEAF = "leaf",
  ROW = "row",
}

---Format the content of a neighbouring panel text
---@param size number
---@param highlight string
---@param text string
---@return string
local function get_panel_text(size, highlight, text)
  if not text then
    text = string.rep(" ", size)
  else
    local text_size = fn.strwidth(text)
    -- 2 here is for padding on either side of the text
    if text_size > size then
      text = " " .. text:sub(1, text_size - size - 2) .. " "
    elseif text_size < size then
      local pad_size = math.floor((size - text_size) / 2)
      local pad = string.rep(" ", pad_size)
      text = pad .. text .. pad
    end
  end
  return highlight .. text
end

---A heuristic to attempt to derive a windows background color from a winhighlight
---@param win_id number
---@param attribute string
---@param match string
---@return string|nil
local function guess_window_highlight(win_id, attribute, match)
  assert(win_id, 'A window id must be passed to "guess_window_highlight"')
  attribute = attribute or "bg"
  match = match or "Normal"
  local hl = vim.wo[win_id].winhighlight
  if not hl then
    return
  end
  local parts = vim.split(hl, ",")
  for _, part in ipairs(parts) do
    local grp, hl_name = unpack(vim.split(part, ":"))
    if grp and grp:match(match) then
      return hl_name
    end
  end
  return match
end

--- Test if the windows within a layout row contain the correct panel buffer
--- NOTE: this only tests the first and last windows as those are the only
--- ones that it makes sense to add a panel for
---@param windows table[]
---@param panel table
---@return boolean
---@return number
---@return boolean
local function is_panel(windows, panel)
  local wins = {windows[1]}
  if #windows > 1 then
    wins[#wins+1] = windows[#windows]
  end
  for idx, win in ipairs(wins) do
    local _type, win_id = win[1], win[2]
    if _type == t.LEAF and type(win_id) == "number" then
      local buf = api.nvim_win_get_buf(win_id)
      local valid = buf and vim.bo[buf].filetype == panel.filetype
      local is_left = idx == 1
      if valid then
        return valid, win_id, is_left
      end
    end
  end
  return false, nil, nil
end

---Calculate the size of padding required to offset the bufferline
---@param prefs table
---@return number
---@return string
---@return string
function M.get(prefs)
  local panels = prefs.options.panels

  local left = ""
  local right = ""
  local total_size = 0

  if panels and #panels > 0 then
    local layout = fn.winlayout()
    for _, panel in ipairs(panels) do
      -- don't bother proceeding if there are no vertical splits
      if layout[1] == t.ROW then
        local is_valid, win_id, is_left = is_panel(layout[2], panel)
        if is_valid then
          local win_width = api.nvim_win_get_width(win_id)
          local sign_width = vim.wo[win_id].signcolumn and 1 or 0

          local hl_name = panel.highlight
            or guess_window_highlight(win_id)
            or prefs.highlights.fill.hl

          local hl = require("bufferline.highlights").hl(hl_name)

          local size = win_width + sign_width
          total_size = total_size + size
          local component = get_panel_text(size, hl, panel.text)

          if is_left then
            left = component
          else
            right = component
          end
        end
      end
    end
  end
  return total_size, left, right
end

return M
