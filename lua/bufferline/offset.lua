local M = {}

local api = vim.api
local fn = vim.fn

local t = {
  LEAF = "leaf",
  ROW = "row",
}

---Format the content of a neighbouring offset's text
---@param size number
---@param highlight string
---@param offset table
---@return string
local function get_section_text(size, highlight, offset)
  local text = offset.text
  local alignment = offset.text_align or "center"
  if not text then
    text = string.rep(" ", size)
  else
    local text_size = fn.strwidth(text)
    local left, right
    if text_size + 2 >= size then
      text = text:sub(1, size - 2)
      left, right = 1, 1
    else
      local remainder = size - text_size
      local is_even, side = remainder % 2 == 0, remainder / 2
      if alignment == "center" then
        left, right = side, side
        if not is_even then
          left, right = math.ceil(side), math.floor(side)
        end
      elseif alignment == "left" then
        left, right = 1, remainder - 1
      else
        left, right = remainder - 1, 1
      end
    end
    text = string.rep(" ", left) .. text .. string.rep(" ", right)
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
---@param offset table
---@return boolean
---@return number
---@return boolean
local function is_offset_section(windows, offset)
  local wins = { windows[1] }
  if #windows > 1 then
    wins[#wins + 1] = windows[#windows]
  end
  for idx, win in ipairs(wins) do
    local _type, win_id = win[1], win[2]
    if _type == t.LEAF and type(win_id) == "number" then
      local buf = api.nvim_win_get_buf(win_id)
      local valid = buf and vim.bo[buf].filetype == offset.filetype
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
  local offsets = prefs.options.offsets

  local left = ""
  local right = ""
  local total_size = 0

  if offsets and #offsets > 0 then
    local layout = fn.winlayout()
    for _, offset in ipairs(offsets) do
      -- don't bother proceeding if there are no vertical splits
      if layout[1] == t.ROW then
        local is_valid, win_id, is_left = is_offset_section(layout[2], offset)
        if is_valid then
          local width = api.nvim_win_get_width(win_id) + (offset.padding or 0)

          local hl_name = offset.highlight
            or guess_window_highlight(win_id)
            or prefs.highlights.fill.hl

          local hl = require("bufferline.highlights").hl(hl_name)
          local component = get_section_text(width, hl, offset)

          total_size = total_size + width

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
