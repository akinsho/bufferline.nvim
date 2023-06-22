local config = require("bufferline.config") ---@module "bufferline.config"

local M = {}
---------------------------------------------------------------------------//
-- Sorters
---------------------------------------------------------------------------//
local api, fn = vim.api, vim.fn

---@param path string
local function full_path(path) return fn.fnamemodify(path, ":p") end

---@param path string
local function is_relative_path(path) return full_path(path) ~= path end

---@type bufferline.Sorter
local function sort_by_extension(a, b) return fn.fnamemodify(a.name, ":e") < fn.fnamemodify(b.name, ":e") end

---@type bufferline.Sorter
local function sort_by_relative_directory(a, b)
  local ra = is_relative_path(a.path)
  local rb = is_relative_path(b.path)
  if ra and not rb then return false end
  if rb and not ra then return true end
  return a.path < b.path
end

---@type bufferline.Sorter
local function sort_by_directory(a, b) return full_path(a.path) < full_path(b.path) end

---@type bufferline.Sorter
local function sort_by_id(a, b)
  if not a and b then
    return true
  elseif a and not b then
    return false
  end
  return a.id < b.id
end

--- @param buf bufferline.Buffer
local function get_buf_tabnr(buf)
  local maxinteger = 1000000000
  -- If the buffer is visible, then its initial value shouldn't be
  -- maxed to prevent sorting it to the end of the list.
  if next(fn.win_findbuf(buf.id)) ~= nil then return 0 end
  -- We use the max integer as a default tab number for hidden buffers,
  -- to order them at the end of the buffer list, since they won't be
  -- found in tab pages.
  return maxinteger
end

---@type bufferline.Sorter
local function sort_by_tabpage_number(a, b)
  local tab_a = api.nvim_tabpage_get_number(a.id)
  local tab_b = api.nvim_tabpage_get_number(b.id)
  return tab_a < tab_b
end

---@type bufferline.Sorter
local function sort_by_tabs(a, b)
  local buf_a_tabnr = get_buf_tabnr(a)
  local buf_b_tabnr = get_buf_tabnr(b)

  local tabs = fn.gettabinfo()
  for _, tab in ipairs(tabs) do
    local buffers = fn.tabpagebuflist(tab.tabnr)
    if buffers ~= 0 then
      for _, buf_id in ipairs(buffers) do
        if buf_id == a.id then
          buf_a_tabnr = tab.tabnr
        elseif buf_id == b.id then
          buf_b_tabnr = tab.tabnr
        end
      end
    end
  end

  return buf_a_tabnr < buf_b_tabnr
end

--- sorts a list of buffers in place
--- @param elements bufferline.TabElement[]
--- @param sort_by (string|function)?
function M.sort(elements, sort_by)
  sort_by = sort_by or config.options.sort_by
  if sort_by == "none" then
    return elements
  elseif sort_by == "extension" then
    table.sort(elements, sort_by_extension)
  elseif sort_by == "directory" then
    table.sort(elements, sort_by_directory)
  elseif sort_by == "relative_directory" then
    table.sort(elements, sort_by_relative_directory)
  elseif sort_by == "id" then
    table.sort(elements, sort_by_id)
  elseif sort_by == "tabs" then
    table.sort(elements, config:is_tabline() and sort_by_tabpage_number or sort_by_tabs)
  elseif type(sort_by) == "function" then
    table.sort(elements, sort_by)
  end
  for index, buf in ipairs(elements) do
    buf.ordinal = index
  end
  return elements
end

return M
