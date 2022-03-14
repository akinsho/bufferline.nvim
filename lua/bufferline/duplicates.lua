local M = {}

local lazy = require("bufferline.lazy")
-- @module "bufferline.config"
local config = lazy.require("bufferline.config")

local strwidth = vim.fn.strwidth

local duplicates = {}

function M.reset()
  duplicates = {}
end

--- This function marks any duplicate buffers granted
--- the buffer names have changes
---@param buffers Buffer[]
---@return Buffer[]
function M.mark(buffers)
  return vim.tbl_map(function(current)
    -- Do not attempt to mark unnamed files
    if current.path == "" then
      return current
    end
    local duplicate = duplicates[current.name]
    if not duplicate then
      duplicates[current.name] = { current }
    else
      local depth = 1
      local limit = 10
      for _, buf in ipairs(duplicate) do
        local buf_depth = 1
        while current:ancestor(buf_depth) == buf:ancestor(buf_depth) do
          -- short circuit if we have gone up 10 directories, we don't expect to have
          -- to look that far to find a non-matching ancestor and we might be looping
          -- endlessly
          if buf_depth >= limit then
            return
          end

          buf_depth = buf_depth + 1
        end
        if buf_depth > depth then
          depth = buf_depth
        end
        buf.duplicated = true
        buf.prefix_count = buf_depth
        buffers[buf.ordinal] = buf
      end
      current.duplicated = true
      current.prefix_count = depth
      table.insert(duplicate, current)
    end
    return current
  end, buffers)
end

--- @param dir string
--- @param depth number
--- @param max_size number
local function truncate(dir, depth, max_size)
  if #dir <= max_size then
    return dir
  end
  local marker = "…"
  -- we truncate any section of the ancestor which is too long
  -- by dividing the allotted space for each section by the depth i.e.
  -- the amount of ancestors which will be prefixed
  local allowed_size = math.ceil(max_size / depth)
  return dir:sub(0, allowed_size - strwidth(marker)) .. marker
end

--- @param context RenderContext
function M.component(context)
  local element = context.tab
  local component = context.component
  local hl = context.current_highlights
  local length = context.length
  local options = config.options
  -- there is no way to enforce a regular tab size as specified by the
  -- user if we are going to potentially increase the tab length by
  -- prefixing it with the parent dir(s)
  if element.duplicated and not options.enforce_regular_tabs then
    local dir = element:ancestor(element.prefix_count, function(dir, depth)
      return truncate(dir, depth, options.max_prefix_length)
    end)
    component = hl.duplicate .. dir .. hl.background .. component
    length = length + strwidth(dir)
  end
  return context:update({ component = component, length = length })
end

return M
