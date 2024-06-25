local lazy = require("bufferline.lazy")
local config = require("bufferline.config") ---@module "bufferline.config"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local highlights = lazy.require("bufferline.highlights") ---@module "bufferline.highlights"
local constants = lazy.require("bufferline.constants") ---@module "bufferline.constants"

local M = {}

local api = vim.api
local fn = vim.fn
local padding = constants.padding

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
---@param win_id integer
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

---@param windows {wincol: number, winrow: number, bufnr: number, winid: number, width: number}[]
---@param offset table
---@return boolean valid
---@return number? win_id
---@return boolean? is_left
local function is_offset_section(windows, offset)
  local last = windows[1]
  for _, win in ipairs(windows) do
    if win.winrow == 2 then
      if vim.bo[win.bufnr].filetype == offset.filetype then
        if win.wincol > last.wincol then last = win end
        if win.wincol == 1 then return true, win.winid, true end
      end
    end
  end
  if last.wincol > 1 then return true, last.winid, false end
  return false
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

  -- wininfo tells us whether or not a window is on the top level or not of the layout
  -- if it is on the top level and it is at the end or beginning it is an offset
  local wininfo = vim.tbl_filter(function(win) return fn.win_gettype(win.winnr) == "" end, fn.getwininfo())

  if offsets and #offsets > 0 then
    for _, offset in ipairs(offsets) do
      -- don't bother proceeding if there are no vertical splits
      local is_valid, win_id, is_left = is_offset_section(wininfo, offset)
      if is_valid and win_id then
        local width = api.nvim_win_get_width(win_id) + (offset.padding or 0)

        local hl_name = offset.highlight or guess_window_highlight(win_id) or config.highlights.fill.hl_group

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
  return {
    left = left,
    right = right,
    left_size = left_size,
    right_size = right_size,
    total_size = total_size,
  }
end

return M
