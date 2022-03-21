local config = require("bufferline.config")

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
  return fnamemodify(buf_a.name, ":e") < fnamemodify(buf_b.name, ":e")
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

--- @param buf_a Buffer
--- @param buf_b Buffer
local function sort_by_id(buf_a, buf_b)
  if not buf_a and buf_b then
    return true
  elseif buf_a and not buf_b then
    return false
  end
  return buf_a.id < buf_b.id
end

--- @param buf Buffer
local function init_buffer_tabnr(buf)
  local maxinteger = 1000000000
  -- If the buffer is visible, then its initial value shouldn't be
  -- maxed to prevent sorting it to the end of the list.
  if next(vim.fn.win_findbuf(buf.id)) ~= nil then
    return 0
  end
  -- We use the max integer as a default tab number for hidden buffers,
  -- to order them at the end of the buffer list, since they won't be
  -- found in tab pages.
  return maxinteger
end

--- @param buf_a Buffer
--- @param buf_b Buffer
local function sort_by_tabs(buf_a, buf_b)
  local buf_a_tabnr = init_buffer_tabnr(buf_a)
  local buf_b_tabnr = init_buffer_tabnr(buf_b)

  local tabs = vim.fn.gettabinfo()
  for _, tab in ipairs(tabs) do
    local buffers = vim.fn.tabpagebuflist(tab.tabnr)
    if buffers ~= 0 then
      for _, buf_id in ipairs(buffers) do
        if buf_id == buf_a.id then
          buf_a_tabnr = tab.tabnr
        elseif buf_id == buf_b.id then
          buf_b_tabnr = tab.tabnr
        end
      end
    end
  end

  return buf_a_tabnr < buf_b_tabnr
end

--- sorts a list of buffers in place
--- @param elements TabElement[]
--- @param sort_by string?
function M.sort(elements, sort_by)
  sort_by = sort_by or config.options.sort_by
  if sort_by == "extension" then
    table.sort(elements, sort_by_extension)
  elseif sort_by == "directory" then
    table.sort(elements, sort_by_directory)
  elseif sort_by == "relative_directory" then
    table.sort(elements, sort_by_relative_directory)
  elseif sort_by == "id" then
    table.sort(elements, sort_by_id)
  elseif sort_by == "tabs" then
    table.sort(elements, config:is_tabline() and sort_by_id or sort_by_tabs)
  elseif type(sort_by) == "function" then
    table.sort(elements, sort_by)
  end
  for index, buf in ipairs(elements) do
    buf.ordinal = index
  end
  return elements
end

return M
