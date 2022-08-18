local M = {}
---------------------------------------------------------------------------//
-- Constants
---------------------------------------------------------------------------//
M.padding = " "

M.indicator = "▎"

M.sep_names = {
  thin = "thin",
  thick = "thick",
  slant = "slant",
  padded_slant = "padded_slant",
}

---@type table<string, string[]>
M.sep_chars = {
  [M.sep_names.thin] = { "▏", "▕" },
  [M.sep_names.thick] = { "▌", "▐" },
  [M.sep_names.slant] = { "", "" },
  [M.sep_names.padded_slant] = { "" .. M.padding, "" .. M.padding },
}

M.positions_key = "BufferlinePositions"

M.visibility = {
  SELECTED = 3,
  INACTIVE = 2,
  NONE = 1,
}

M.FOLDER_ICON = ""

M.ELLIPSIS = "…"

return M
