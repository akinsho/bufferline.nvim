local M = {}

---@alias grouper fun(b: Buffer): boolean

---@class Group
---@field name string
---@field fn grouper
---@field highlight string

---Group buffers based on user criteria
---@param buffer Buffer
---@param groups Group[]
function M.get(buffer, groups)
  if not groups or #groups < 1 then
    return
  end
  for _, grp in ipairs(groups) do
    if grp(buffer) then
      return grp
    end
  end
end

return M
