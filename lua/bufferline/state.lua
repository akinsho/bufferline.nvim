local M = {}

-----------------------------------------------------------------------------//
-- State
-----------------------------------------------------------------------------//
---@class BufferlineState
---@field components Component[]
---@field current_element_index number?
---@field visible_components Component[]
---@field __components Component[]
---@field __visible_components Component[]
---@field custom_sort number[]
local state = {
  is_picking = false,
  current_element_index = nil,
  custom_sort = nil,
  __components = {},
  __visible_components = {},
  components = {},
  visible_components = {},
}

---@param value BufferlineState
function M.set(value)
  state = vim.tbl_extend("force", state, value)
end

function M.get()
  return state
end

return setmetatable(M, {
  __index = function(_, k)
    return state[k]
  end,
})
