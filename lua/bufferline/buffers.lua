local lazy = require("bufferline.lazy")
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local groups = lazy.require("bufferline.groups") ---@module "bufferline.groups"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local pick = require("bufferline.pick") ---@module "bufferline.pick"
local duplicates = require("bufferline.duplicates") ---@module "bufferline.duplicates"
local diagnostics = require("bufferline.diagnostics") ---@module "bufferline.diagnostics"
local models = require("bufferline.models") ---@module "bufferline.models"

local M = {}

local api = vim.api

--- sorts buf_nums in place, according to state.custom_sort
--- @param buf_nums number[]
--- @param state bufferline.State
local function sort_buffers(buf_nums, state)
  local opts = config.options
  local sort_by = opts.sort_by
  local sorted = state.custom_sort or {}
  local reverse_lookup_sorted = utils.tbl_reverse_lookup(sorted)

  local comp
  if sort_by == "insert_at_end" then
    -- a comparator that sorts buffers by their position in sorted
    -- will also ensure any new buffers are placed at the end
    comp = function(buf_a, buf_b)
      local a_index = reverse_lookup_sorted[buf_a]
      local b_index = reverse_lookup_sorted[buf_b]
      if a_index and b_index then
        return a_index < b_index
      elseif a_index and not b_index then
        return true
      elseif not a_index and b_index then
        return false
      end
      return buf_a < buf_b
    end
  elseif sort_by == "insert_after_current" then
    local current_index = state.current_element_index or 1
    -- a comparator that sorts buffers by their position in sorted
    -- will also ensure any new buffers are placed after the current buffer
    comp = function(buf_a, buf_b)
      local a_index = reverse_lookup_sorted[buf_a]
      local b_index = reverse_lookup_sorted[buf_b]
      if a_index and b_index then
        -- If both buffers are either before or after (inclusive) the current buffer, respect the sorted order.
        if (a_index - current_index) * (b_index - current_index) >= 0 then return a_index < b_index end
        return a_index < current_index
      elseif a_index and not b_index then
        return a_index <= current_index
      elseif not a_index and b_index then
        return current_index < b_index
      end
      return buf_a < buf_b
    end
  else
    -- if there's no custom sort, we have nothing to do
    if not state.custom_sort then return end

    -- a comparator that sorts buffers by their position in sorted
    comp = function(buf_id_1, buf_id_2)
      local buf_1_rank = reverse_lookup_sorted[buf_id_1]
      local buf_2_rank = reverse_lookup_sorted[buf_id_2]
      if not buf_1_rank then return false end
      if not buf_2_rank then return true end
      return buf_1_rank < buf_2_rank
    end
  end

  table.sort(buf_nums, comp)

  -- save the new custom sort
  state.custom_sort = buf_nums
  if opts.persist_buffer_sort then utils.save_positions(state.custom_sort) end
end

---Filter the buffers to show based on the user callback passed in
---@param buf_nums integer[]
---@param callback fun(buf: integer, bufs: integer[]): boolean
---@return integer[]
local function apply_buffer_filter(buf_nums, callback)
  if type(callback) ~= "function" then return buf_nums end
  local filtered = {}
  for _, buf in ipairs(buf_nums) do
    if callback(buf, buf_nums) then table.insert(filtered, buf) end
  end
  return filtered
end

---Return a list of the buffers open in nvim as Components
---@param state bufferline.State
---@return bufferline.Buffer[]
function M.get_components(state)
  local options = config.options
  local buf_nums = utils.get_valid_buffers()
  local filter = options.custom_filter
  buf_nums = filter and apply_buffer_filter(buf_nums, filter) or buf_nums
  sort_buffers(buf_nums, state)

  pick.reset()
  duplicates.reset()
  ---@type bufferline.Buffer[]
  local components = {}
  local all_diagnostics = diagnostics.get(options)
  local Buffer = models.Buffer
  for i, buf_id in ipairs(buf_nums) do
    local buf = Buffer:new({
      path = api.nvim_buf_get_name(buf_id),
      id = buf_id,
      ordinal = i,
      diagnostics = all_diagnostics[buf_id],
      name_formatter = options.name_formatter,
    })
    buf.letter = pick.get(buf)
    buf.group = groups.set_id(buf)
    components[i] = buf
  end

  return vim.tbl_map(function(buf) return ui.element(state, buf) end, duplicates.mark(components))
end

return M
