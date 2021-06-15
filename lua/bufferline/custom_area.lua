local M = {}
local fn = vim.fn
local fmt = string.format

---generate a custom highlight group
---@param index integer
---@param side string
---@param section table
---@param guibg string
local function create_hl(index, side, section, guibg)
  local name = fmt("BufferLine%sCustomAreaText%d", side:gsub("^%l", string.upper), index)
  local H = require("bufferline.highlights")
  H.set_one(name, {
    guifg = section.guifg,
    guibg = section.guibg or guibg,
    gui = section.gui,
  })
  return H.hl(name)
end

---Create tabline segment for custom user specified sections
---@param prefs table
---@return integer
---@return string
---@return string
function M.get(prefs)
  local size = 0
  local left = ""
  local right = ""
  ---@type table<string,function>
  local areas = prefs.options.custom_areas
  if areas then
    for side, section_fn in pairs(areas) do
      if type(section_fn) ~= "function" then
        return require("bufferline.utils").echoerr(
          fmt("each side should be a function but you passed in %s", vim.inspect(side))
        )
      end
      -- if the user doesn't specify a background use the default
      local hls = prefs.highlights or {}
      local guibg = hls.fill and hls.fill.guibg or nil
      local ok, section = pcall(section_fn)
      if ok and section and not vim.tbl_isempty(section) then
        for i, item in ipairs(section) do
          if item.text and type(item.text) == "string" then
            local hl = create_hl(i, side, item, guibg)
            size = size + fn.strwidth(item.text)
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
