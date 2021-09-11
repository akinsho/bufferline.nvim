local utils = require("bufferline.utils")
local Buffer = require("bufferline.models").Buffer
local pick = require("bufferline.pick")
local duplicates = require("bufferline.duplicates")
local diagnostics = require("bufferline.diagnostics")
local groups = require("bufferline.groups")

local M = {}

---Filter the buffers to show based on the user callback passed in.
---@param buf_nums integer[]
---@param callback fun(buf: integer, bufs: integer[]): boolean
---@return integer[]
local function filter_buffer_numbers(buf_nums, callback)
  if type(callback) ~= "function" then
    return buf_nums
  end

  local filtered = {}

  for _, buf in ipairs(buf_nums) do
    if callback(buf, buf_nums) then
      table.insert(filtered, buf)
    end
  end

  return filtered
end

--- Sorts buf_names in place using the provided sorted table. Doesn't add or remove any values.
--- @param buf_nums integer[]
--- @param sorted integer[]
--- @return integer[]
local function sort_buffer_numbers(buf_nums, sorted)
  if not sorted then
    return buf_nums
  end

  local nums = { unpack(buf_nums) }
  local reverse_lookup_sorted = utils.tbl_reverse_lookup(sorted)

  --- a comparator that sorts buffers by their position in sorted
  local sort_by_sorted = function(buf_id_1, buf_id_2)
    local buf_1_rank = reverse_lookup_sorted[buf_id_1]
    local buf_2_rank = reverse_lookup_sorted[buf_id_2]
    if not buf_1_rank then
      return false
    end
    if not buf_2_rank then
      return true
    end
    return buf_1_rank < buf_2_rank
  end

  table.sort(nums, sort_by_sorted)

  return nums
end

--- Returns the current valid buffer numbers.
---@param custom_filter fun(buf: integer, bufs: integer[]): boolean
---@param custom_sort integer[]
---@return integer[]
local get_valid_buffer_numbers = function(custom_filter, custom_sort)
  local buf_nums = vim.api.nvim_list_bufs()

  buf_nums = filter_buffer_numbers(buf_nums, custom_filter)
  buf_nums = sort_buffer_numbers(buf_nums, custom_sort)

  -- NOTE: In Lua in order to iterate an array, indices should
  -- not contain gaps otherwise "ipairs" will stop at the first gap
  -- i.e the indices should be contiguous
  local index = 0
  local valid_bufs = {}

  for _, buf in ipairs(buf_nums) do
    if M.is_valid(buf) then
      index = index + 1
      valid_bufs[index] = buf
    end
  end

  return valid_bufs
end

--- Returns the current valid buffers.
--- @param config BufferlineConfig
--- @return Buffer[]
function M.get_valid_buffers(config)
  local options = config.options or {}
  local has_groups = config:enabled("groups")
  pick.reset()
  duplicates.reset()

  local buffer_numbers = get_valid_buffer_numbers(options.custom_filter, options.custom_sort)

  --- @type Buffer[]
  local buffers = {}

  local all_diagnostics = diagnostics.get(options)

  for i, buffer_id in ipairs(buffer_numbers) do
    local buffer = Buffer:new({
      path = vim.fn.bufname(buffer_id),
      id = buffer_id,
      ordinal = i,
      diagnostics = all_diagnostics[buffer_id],
      name_formatter = options.name_formatter,
    })

    buffer.letter = pick.get(buffer)

    if has_groups then
      buffer.group = groups.set_id(buffer)
    end

    buffers[i] = buffer
  end

  return duplicates.mark(buffers)
end

return M
