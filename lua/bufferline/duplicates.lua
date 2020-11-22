local M = {}

local duplicates = {}

function M.reset()
  duplicates = {}
end

local cache = {}
setmetatable(cache, {__mode = "v"}) -- make values weak

---@param buffers table<Buffer>
---@param current Buffer
---@param callback function(Buffer)
local function mark_duplicates(buffers, current, callback)
  local duplicate = duplicates[current.filename]
  if not duplicate then
    duplicates[current.filename] = {current}
  else
    local depth = 1
    for _, buf in ipairs(duplicate) do
      local buf_depth = 1
      while current:ancestor(buf_depth) == buf:ancestor(buf_depth) do
        buf_depth = buf_depth + 1
      end
      if buf_depth > depth then
        depth = buf_depth
      end
      buf.duplicated = buf_depth
      -- if the buffer is a duplicate we have to redraw it with the new name
      callback(buf)
      buffers[buf.ordinal] = buf
    end
    current.duplicated = depth
    table.insert(duplicate, current)
  end
end

local function get_key(buffers)
  return table.concat(
    vim.tbl_map(
      function(buf)
        return buf.filename
      end,
      buffers
    ),
    "-"
  )
end

--- This function marks any duplicate buffers granted
--- the buffer names have changes
function M.mark(buffers, ...)
  local value = cache[get_key(buffers)]
  if value then
    return
  else
    mark_duplicates(buffers, ...)
  end
end

return M
