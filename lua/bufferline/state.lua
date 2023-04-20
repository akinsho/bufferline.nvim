local M = {}

local lazy = require("bufferline.lazy")
local constants = lazy.require("bufferline.constants") ---@module "bufferline.constants"

-----------------------------------------------------------------------------//
-- State
-----------------------------------------------------------------------------//

---@type bufferline.State
local state = {
  is_picking = false,
  hovered = nil,
  custom_sort = nil,
  current_element_index = nil,
  components = {},
  __components = {},
  visible_components = {},
  left_offset_size = 0,
  right_offset_size = 0,
}

function M.restore_positions()
  local str = vim.g[constants.positions_key]
  if not str then return str end
  -- these are converted to strings when stored
  -- so have to be converted back before usage
  local ids = vim.split(str, ",")
  if ids and #ids > 0 then state.custom_sort = vim.tbl_map(tonumber, ids) end
end

---@param new_state bufferline.State
function M.set(new_state)
  for key, value in pairs(new_state) do
    if value == vim.NIL then value = nil end
    state[key] = value
  end
end

return setmetatable(M, {
  __index = function(_, k) return state[k] end,
})
