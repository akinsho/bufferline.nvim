---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local function hl(item)
  return "%#" .. item .. "#"
end

local M = {
  fill = hl("BufferLineFill"),
  inactive = hl("BufferLineInactive"),
  tab = hl("BufferLineTab"),
  duplicate = hl("BufferLineDuplicate"),
  duplicate_inactive = hl("BufferLineDuplicateInactive"),
  tab_selected = hl("BufferLineTabSelected"),
  selected = hl("BufferLineSelected"),
  indicator = hl("BufferLineSelectedIndicator"),
  modified = hl("BufferLineModified"),
  modified_inactive = hl("BufferLineModifiedInactive"),
  modified_selected = hl("BufferLineModifiedSelected"),
  pick = hl("BufferLinePick"),
  pick_inactive = hl("BufferLinePickInactive"),
  diagnostic = hl("ErrorMsg"),
  background = hl("BufferLineBackground"),
  separator = hl("BufferLineSeparator"),
  selected_separator = hl("BufferLineSelectedSeparator"),
  close = hl("BufferLineTabClose") .. "%999X"
}

return M
