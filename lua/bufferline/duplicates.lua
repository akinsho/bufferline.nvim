local M = {}

local lazy = require("bufferline.lazy")
-- @module "bufferline.config"
local config = lazy.require("bufferline.config")
-- @module "bufferline.utils"
local utils = require("bufferline.utils")

local duplicates = {}

local api = vim.api

function M.reset() duplicates = {} end

local function is_same_path(a, b, depth)
  local a_path = vim.split(a, utils.path_sep)
  local b_path = vim.split(b, utils.path_sep)
  local a_index = depth <= #a_path and (#a_path - depth) + 1 or 1
  local b_index = depth <= #b_path and (#b_path - depth) + 1 or 1
  return b_path[b_index] == a_path[a_index]
end
--- This function marks any duplicate buffers granted
--- the buffer names have changes
---@param elements TabElement[]
---@return TabElement[]
function M.mark(elements)
  return utils.map(function(current)
    if current.path == "" then return current end
    local duplicate = duplicates[current.name]
    if not duplicate then
      duplicates[current.name] = { current }
    else
      local depth, limit, is_same_buffer = 1, 10, false
      for _, element in ipairs(duplicate) do
        local element_depth = 1
        is_same_buffer = current.path == element.path
        while is_same_path(current.path, element.path, element_depth) and not is_same_buffer do
          if element_depth >= limit then break end
          element_depth = element_depth + 1
        end
        if element_depth > depth then depth = element_depth end
        elements[element.ordinal].prefix_count = element_depth
        elements[element.ordinal].duplicated = is_same_buffer and "element" or "path"
      end
      current.prefix_count = depth
      current.duplicated = is_same_buffer and "element" or "path"
      duplicate[#duplicate + 1] = current
    end
    return current
  end, elements)
end

--- @param dir string
--- @param depth number
--- @param max_size number
local function truncate(dir, depth, max_size)
  if api.nvim_strwidth(dir) <= max_size then return dir end
  -- we truncate any section of the ancestor which is too long
  -- by dividing the allotted space for each section by the depth i.e.
  -- the amount of ancestors which will be prefixed
  local allowed_size = math.floor(max_size / depth) + 1 -- Add one to account for the path separator
  local truncated = utils.map(
    function(part) return utils.truncate_name(part, allowed_size) end,
    vim.split(dir, utils.path_sep)
  )
  return table.concat(truncated, utils.path_sep)
end

--- @param context RenderContext
--- @return Segment?
function M.component(context)
  local element = context.tab
  local hl = context.current_highlights
  local options = config.options
  -- there is no way to enforce a regular tab size as specified by the
  -- user if we are going to potentially increase the tab length by
  -- prefixing it with the parent dir(s)
  if element.duplicated and options.show_duplicate_prefix and not options.enforce_regular_tabs then
    local dir = element:ancestor(
      element.prefix_count,
      function(dir, depth) return truncate(dir, depth, options.max_prefix_length) end
    )
    return { text = dir, highlight = hl.duplicate }
  end
end

return M
