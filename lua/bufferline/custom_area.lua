local lazy = require("bufferline.lazy")
---@module "bufferline.config"
local config = lazy.require("bufferline.config")
---@module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
---@module "bufferline.highlights"
local highlights = lazy.require("bufferline.highlights")

local M = {}

local api = vim.api
local fmt = string.format

---generate a custom highlight group
---@param index integer
---@param side string
---@param section table
---@param bg string?
local function create_hl(index, side, section, bg)
  local name = fmt("BufferLine%sCustomAreaText%d", side:gsub("^%l", string.upper), index)
  local opts = highlights.translate_user_highlights(section)
  opts.bg = opts.bg or bg
  -- We need to be able to constantly override these highlights so they should always be default
  opts.default = true
  highlights.set_one(name, opts)
  return highlights.hl(name)
end

---@param text string
---@return number
local function get_size(text)
  ---@type table<string, number>
  local data = api.nvim_eval_statusline(text, { use_tabline = true })
  return data.width
end

---Create tabline segment for custom user specified sections
---@return integer
---@return string
---@return string
function M.get()
  local size = 0
  local left = ""
  local right = ""
  ---@type table<string,function>
  local areas = config.options.custom_areas
  if areas then
    for side, section_fn in pairs(areas) do
      if type(section_fn) ~= "function" then
        utils.notify(
          fmt("each side should be a function but you passed in %s", vim.inspect(side)),
          "error"
        )
        return 0, "", ""
      end
      -- if the user doesn't specify a background use the default
      local hls = config.highlights or {}
      local bg = hls.fill and hls.fill.bg or nil
      local ok, section = pcall(section_fn)
      if ok and section and not vim.tbl_isempty(section) then
        for i, item in ipairs(section) do
          if item.text and type(item.text) == "string" then
            local hl = create_hl(i, side, item, bg)
            size = size + get_size(item.text)
            if side == "left" then
              left = left .. hl .. item.text
            else
              right = right .. hl .. item.text
            end
          end
        end
      end
    end
  end
  return size, left, right
end

return M
