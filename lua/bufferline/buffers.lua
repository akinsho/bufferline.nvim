local lazy = require("bufferline.lazy")
--- @module "bufferline.ui"
local ui = lazy.require("bufferline.ui")
--- @module "bufferline.groups"
local groups = lazy.require("bufferline.groups")
--- @module "bufferline.config"
local config = lazy.require("bufferline.config")
--- @module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
--- @module "bufferline.pick"
local pick = require("bufferline.pick")
--- @module "bufferline.duplicates"
local duplicates = require("bufferline.duplicates")
--- @module "bufferline.diagnostics"
local diagnostics = require("bufferline.diagnostics")
--- @module "bufferline.models"
local models = require("bufferline.models")

local M = {}

local api = vim.api

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
---@param state BufferlineState
---@return NvimBuffer[]
function M.get_components(state)
  local options = config.options
  local buf_nums = utils.get_valid_buffers()
  local filter = options.custom_filter
  buf_nums = filter and apply_buffer_filter(buf_nums, filter) or buf_nums
  buf_nums = utils.apply_sort(buf_nums, state.custom_sort)

  pick.reset()
  duplicates.reset()
  ---@type NvimBuffer[]
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
