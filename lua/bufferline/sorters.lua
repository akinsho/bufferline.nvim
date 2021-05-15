local M = {}

---------------------------------------------------------------------------//
-- Sorters
---------------------------------------------------------------------------//
local fnamemodify = vim.fn.fnamemodify

---@param path string
---@return string
local function full_path(path)
  return fnamemodify(path, ":p")
end

---@param path string
---@return string
local function is_relative_path(path)
  return full_path(path) ~= path
end

---Sort buffers by the most recently visited
---comment
---@param recent_visits table<string,number>
---@return function(buf_a: Buffer, buf_b: Buffer): boolean
local function sort_by_recent(recent_visits)
  return function(buf_a, buf_b)
    return recent_visits[buf_a.id] > recent_visits[buf_b.id]
  end
end

--- @param buf_a Buffer
--- @param buf_b Buffer
local function sort_by_extension(buf_a, buf_b)
  return fnamemodify(buf_a.filename, ":e") < fnamemodify(buf_b.filename, ":e")
end

--- @param buf_a Buffer
--- @param buf_b Buffer
local function sort_by_relative_directory(buf_a, buf_b)
  local ra = is_relative_path(buf_a.path)
  local rb = is_relative_path(buf_b.path)
  if ra and not rb then
    return false
  end
  if rb and not ra then
    return true
  end
  return buf_a.path < buf_b.path
end

--- @param buf_a Buffer
--- @param buf_b Buffer
local function sort_by_directory(buf_a, buf_b)
  return full_path(buf_a.path) < full_path(buf_b.path)
end

--- sorts a list of buffers in place
--- @param sort_by string|function
--- @param state table
function M.sort_buffers(sort_by, state)
  --@type Buffers[]
  local buffers = state.buffers
  if sort_by == "extension" then
    table.sort(buffers, sort_by_extension)
  elseif sort_by == "directory" then
    table.sort(buffers, sort_by_directory)
  elseif sort_by == "relative_directory" then
    table.sort(buffers, sort_by_relative_directory)
  elseif sort_by == "recent" then
    table.sort(buffers, sort_by_recent(state.recent_visits))
  elseif type(sort_by) == "function" then
    table.sort(buffers, sort_by)
  end
end

---Setup autocommands for complex sorters
---@param autocommands table[]
---@param sort_by string
function M.setup(autocommands, sort_by)
  if sort_by == "recent" then
    table.insert(autocommands, {
      "BufEnter",
      "*",
      "lua require'bufferline'.count_visit()",
    })
  end
end

return M
