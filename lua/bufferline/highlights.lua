local api = vim.api
local fmt = string.format
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

function M.hl(item)
  return "%#" .. item .. "#"
end

function M.hl_exists(name)
  return vim.fn.hlexists(name) > 0
end

local keys = { "gui", "guisp", "guibg", "guifg" }

function M.set_one(name, opts)
  if not opts or vim.tbl_isempty(opts) then
    return
  end
  local hls = {}
  for key, value in pairs(opts) do
    if value and value ~= "" and vim.tbl_contains(keys, key) then
      table.insert(hls, fmt("%s=%s", key, value))
    end
  end
  local success, err = pcall(vim.cmd, fmt("highlight! %s %s", name, table.concat(hls, " ")))
  if not success then
    vim.notify(
      "Failed setting " .. name .. " highlight, something isn't configured correctly: " .. err,
      vim.log.levels.ERROR
    )
  end
end

---Generate highlight groups from user
---@param highlight table
function M.add_group(name, highlight)
  -- convert 'bufferline_value' to 'BufferlineValue' -> snake to pascal
  local formatted = "BufferLine" .. name:gsub("_(.)", name.upper):gsub("^%l", string.upper)
  highlight.hl_name = formatted
  highlight.hl = M.hl(formatted)
end

--- Map through user colors and convert the keys to highlight names
--- by changing the strings to pascal case and using those for highlight name
--- @param user_colors table
function M.set_all(user_colors)
  for name, tbl in pairs(user_colors) do
    if not tbl or not tbl.hl_name then
      api.nvim_echo({
        {
          ("Error setting highlight group: no name for %s - %s"):format(name, vim.inspect(tbl)),
          "ErrorMsg",
        },
      }, true, {})
    else
      M.set_one(tbl.hl_name, tbl)
    end
  end
end

--- TODO: find a tidier way to do this if possible
---@param element Buffer | Tabpage
---@return table
function M.for_element(element)
  local hl = {}
  local h = require("bufferline.config").get("highlights")
  if element:current() then
    hl.background = h.buffer_selected.hl
    hl.modified = h.modified_selected.hl
    hl.duplicate = h.duplicate_selected.hl
    hl.pick = h.pick_selected.hl
    hl.separator = h.separator_selected.hl
    hl.buffer = h.buffer_selected
    hl.diagnostic = h.diagnostic_selected.hl
    hl.error = h.error_selected.hl
    hl.error_diagnostic = h.error_diagnostic_selected.hl
    hl.warning = h.warning_selected.hl
    hl.warning_diagnostic = h.warning_diagnostic_selected.hl
    hl.info = h.info_selected.hl
    hl.info_diagnostic = h.info_diagnostic_selected.hl
    hl.hint = h.hint_selected.hl
    hl.hint_diagnostic = h.hint_diagnostic_selected.hl
    hl.close_button = h.close_button_selected.hl
  elseif element:visible() then
    hl.background = h.buffer_visible.hl
    hl.modified = h.modified_visible.hl
    hl.duplicate = h.duplicate_visible.hl
    hl.pick = h.pick_visible.hl
    hl.separator = h.separator_visible.hl
    hl.buffer = h.buffer_visible
    hl.diagnostic = h.diagnostic_visible.hl
    hl.error = h.error_visible.hl
    hl.error_diagnostic = h.error_diagnostic_visible.hl
    hl.warning = h.warning_visible.hl
    hl.warning_diagnostic = h.warning_diagnostic_visible.hl
    hl.info = h.info_visible.hl
    hl.info_diagnostic = h.info_diagnostic_visible.hl
    hl.hint = h.hint_visible.hl
    hl.hint_diagnostic = h.hint_diagnostic_visible.hl
    hl.close_button = h.close_button_visible.hl
  else
    hl.background = h.background.hl
    hl.modified = h.modified.hl
    hl.duplicate = h.duplicate.hl
    hl.pick = h.pick.hl
    hl.separator = h.separator.hl
    hl.buffer = h.background
    hl.diagnostic = h.diagnostic.hl
    hl.error = h.error.hl
    hl.error_diagnostic = h.error_diagnostic.hl
    hl.warning = h.warning.hl
    hl.warning_diagnostic = h.warning_diagnostic.hl
    hl.info = h.info.hl
    hl.info_diagnostic = h.info_diagnostic.hl
    hl.hint = h.hint.hl
    hl.hint_diagnostic = h.hint_diagnostic.hl
    hl.close_button = h.close_button.hl
  end

  if element.group then
    require("bufferline.groups").set_current_hl(element, h, hl)
  end

  return hl
end

return M
