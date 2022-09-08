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
local state = {
  is_picking = false,
  current_element_index = nil,
  custom_sort = nil,
  __components = {},
  components = {},
  visible_components = {},
  hovered = nil,
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
