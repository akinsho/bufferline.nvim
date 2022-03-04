local config = require("bufferline.config")

local M = {}

local api = vim.api
local fn = vim.fn

local t = {
  LEAF = "leaf",
  ROW = "row",
  COLUMN = "col",
}

local supported_win_types = {
  [t.LEAF] = true,
  [t.COLUMN] = true,
}

---Format the content of a neighbouring offset's text
---@param size number
---@param highlight string
---@param offset table
---@return string
local function get_section_text(size, highlight, offset)
  local text = offset.text
  if type(text) == "function" then
    text = text()
  end
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
  for i = #parts, 1, -1 do
    local grp, hl_name = unpack(vim.split(parts[i], ":"))
    if grp and grp:match(match) then
      return hl_name
    end
  end
  return match
end

--- This helper checks to see if bufferline supports creating an offset for the given layout
--- Valid window layouts can be
--- * A list of full height splits in a row:
--- `{'row', ['leaf', id], ['leaf', id]}`
--- * A row of splits where one on either edge is not full height but the matching
--- split is on the top:
--- e.g. the vertical tool bar is split in two such as for undo tree
--- `{'row', ['col', ['leaf', id], ['leaf', id]], ['leaf', id]}`
---
---@param windows table[]
---@return boolean
---@return number
local function is_valid_layout(windows)
  local win_type, win_id = windows[1], windows[2]
  if vim.tbl_islist(win_id) and win_type == t.COLUMN then
    win_id = win_id[1][2]
  end
  return supported_win_types[win_type] and type(win_id) == "number", win_id
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
    local valid_layout, win_id = is_valid_layout(win)
    if valid_layout then
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
---@return number
---@return string
---@return string
function M.get()
  local offsets = config.options.offsets
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
            or config.highlights.fill.hl

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
