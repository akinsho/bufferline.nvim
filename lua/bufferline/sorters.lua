local M = {}
---------------------------------------------------------------------------//
-- Sorters
---------------------------------------------------------------------------//
local fnamemodify = vim.fn.fnamemodify

-- @param path string
local function full_path(path)
  return fnamemodify(path, ":p")
end

-- @param path string
local function is_relative_path(path)
  return full_path(path) ~= path
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
--- @param buffers Buffer[]
function M.sort_buffers(sort_by, buffers)
  if sort_by == "extension" then
    table.sort(buffers, sort_by_extension)
  elseif sort_by == "directory" then
    table.sort(buffers, sort_by_directory)
  elseif sort_by == "relative_directory" then
    table.sort(buffers, sort_by_relative_directory)
  elseif type(sort_by) == "function" then
    table.sort(buffers, sort_by)
  end
end

return M
