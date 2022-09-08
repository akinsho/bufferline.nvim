local lazy = require("bufferline.lazy")
---@module "bufferline.config"
local config = require("bufferline.config")
---@module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
---@module "bufferline.highlights"
local highlights = lazy.require("bufferline.highlights")
---@module "bufferline.constants"
local constants = lazy.require("bufferline.constants")

local M = {}

local api = vim.api
local fn = vim.fn
local padding = constants.padding

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
---@param size integer
---@param highlight table<string, string>
---@param offset table
---@param is_left boolean?
---@return string
local function get_section_text(size, highlight, offset, is_left)
  local text = offset.text

  if type(text) == "function" then text = text() end
  text = text or padding:rep(size - 2)

  local text_size, left, right = api.nvim_strwidth(text), 0, 0
  local alignment = offset.text_align or "center"

  if text_size + 2 >= size then
    text, left, right = utils.truncate_name(text, size - 2), 1, 1
  else
    local remainder = size - text_size
    local is_even, side = remainder % 2 == 0, remainder / 2
    if alignment == "center" then
      if not is_even then
        left, right = math.ceil(side), math.floor(side)
      else
        left, right = side, side
      end
    elseif alignment == "left" then
      left, right = 1, remainder - 1
    else
      left, right = remainder - 1, 1
    end
  end
  local str = highlight.text .. padding:rep(left) .. text .. padding:rep(right)
  if not offset.separator then return str end

  local sep_icon = type(offset.separator) == "string" and offset.separator or "│"
  local sep = highlight.sep .. sep_icon
  return (not is_left and sep or "") .. str .. (is_left and sep or "")
end

---A heuristic to attempt to derive a windows background color from a winhighlight
---@param win_id number
---@param attribute string?
---@param match string?
---@return string|nil
local function guess_window_highlight(win_id, attribute, match)
  assert(win_id, 'A window id must be passed to "guess_window_highlight"')
  attribute = attribute or "bg"
  match = match or "Normal"
  local hl = vim.wo[win_id].winhighlight
  if not hl then return end
  local parts = vim.split(hl, ",")
  for i = #parts, 1, -1 do
    local grp, hl_name = unpack(vim.split(parts[i], ":"))
    if grp and grp:match(match) then return hl_name end
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
  if vim.tbl_islist(win_id) and win_type == t.COLUMN then win_id = win_id[1][2] end
  return supported_win_types[win_type] and type(win_id) == "number", win_id
end

--- Test if the windows within a layout row contain the correct panel buffer
--- NOTE: this only tests the first and last windows as those are the only
--- ones that it makes sense to add a panel for
---@param windows table[]
---@param offset table
---@return boolean
---@return number?
---@return boolean?
local function is_offset_section(windows, offset)
  local wins = { windows[1] }
  if #windows > 1 then wins[#wins + 1] = windows[#windows] end
  for idx, win in ipairs(wins) do
    local valid_layout, win_id = is_valid_layout(win)
    if valid_layout then
      local buf = api.nvim_win_get_buf(win_id)
      local valid = buf and vim.bo[buf].filetype == offset.filetype
      local is_left = idx == 1
      if valid then return valid, win_id, is_left end
    end
  end
  return false, nil, nil
end

---@class OffsetData
---@field total_size number
---@field left string
---@field right string
---@field left_size integer
---@field right_size integer

---Calculate the size of padding required to offset the bufferline
---@return OffsetData
function M.get()
  local offsets, hls = config.options.offsets, config.highlights
  local left = ""
  local right = ""
  local left_size = 0
  local right_size = 0
  local total_size = 0
  local sep_hl = highlights.hl(hls.offset_separator.hl_group)

  if offsets and #offsets > 0 then
    local layout = fn.winlayout()
    for _, offset in ipairs(offsets) do
      -- don't bother proceeding if there are no vertical splits
      if layout[1] == t.ROW then
        local is_valid, win_id, is_left = is_offset_section(layout[2], offset)
        if is_valid and win_id then
          local width = api.nvim_win_get_width(win_id) + (offset.padding or 0)

          local hl_name = offset.highlight
            or guess_window_highlight(win_id)
            or config.highlights.fill.hl_group

          local hl = highlights.hl(hl_name)
          local component = get_section_text(width, { text = hl, sep = sep_hl }, offset, is_left)

          total_size = total_size + width

          if is_left then
            left, left_size = component, left_size + width
          else
            right, right_size = component, right_size + width
          end
        end
      end
    end
  end
  return {
    left = left,
    right = right,
    left_size = left_size,
    right_size = right_size,
    total_size = total_size,
  }
end

return M
