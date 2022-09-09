local M = {}

-----------------------------------------------------------------------------//
-- State
-----------------------------------------------------------------------------//

---@class BufferlineState
---@field components Component[]
---@field current_element_index number?
---@field visible_components Component[]
---@field __components Component[]
---@field custom_sort number[]
---@field left_offset_size number
---@field right_offset_size number
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

---@param new_state BufferlineState
function M.set(new_state)
  for key, value in pairs(new_state) do
    if value == vim.NIL then value = nil end
    state[key] = value
  end
end

return setmetatable(M, {
  __index = function(_, k) return state[k] end,
})
