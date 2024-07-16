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

---@param components bufferline.TabElement[]
---@return bufferline.Sorter
local sort_by_new_after_existing = function(components)
  return function(item_a, item_b)
    if item_a:newly_opened(components) and item_b:previously_opened(components) then
      return false
    elseif item_a:previously_opened(components) and item_b:newly_opened(components) then
      return true
    end
    return item_a.id < item_b.id
  end
end

---@param prev_components bufferline.TabElement[]
---@return bufferline.Sorter
local sort_by_new_after_current = function(prev_components, current_index)
  return function(item_a, item_b)
    local a_index = item_a:find_index(prev_components)
    local a_is_new = item_a:newly_opened(prev_components)
    local b_index = item_b:find_index(prev_components)
    local b_is_new = item_b:newly_opened(prev_components)
    current_index = current_index or 1
    if not a_is_new and not b_is_new then
      -- If both buffers are either before or after (inclusive) the current buffer, respect the current order.
      if (a_index - current_index) * (b_index - current_index) >= 0 then return a_index < b_index end
      return a_index < current_index
    elseif not a_is_new and b_is_new then
      return a_index <= current_index
    elseif a_is_new and not b_is_new then
      return current_index < b_index
    end
    return item_a.id < item_b.id
  end
end

--- sorts a list of buffers in place
--- @param elements bufferline.TabElement[]
--- @param opts bufferline.SorterOptions
function M.sort(elements, opts)
  opts = opts or {}
  local sort_by = opts.sort_by or config.options.sort_by
  -- the user has manually sorted the buffers don't try to re-sort them
  if opts.custom_sort then return elements end
  if sort_by == "none" then
    return elements
  elseif sort_by == "insert_after_current" then
    table.sort(elements, sort_by_new_after_current(opts.prev_components, opts.current_index))
  elseif sort_by == "insert_at_end" then
    table.sort(elements, sort_by_new_after_existing(opts.prev_components))
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
