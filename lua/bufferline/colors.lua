local M = {}

local bit = require("bit")
local fmt = string.format

---Convert a hex color to rgb
---@param color string
---@return number
---@return number
---@return number
local function hex_to_rgb(color)
  local hex = color:gsub("#", "")
  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5), 16)
end

local function alter(attr, percent) return math.floor(attr * (100 + percent) / 100) end

---@source https://stackoverflow.com/q/5560248
---@see: https://stackoverflow.com/a/37797380
---Darken a specified hex color
---@param color string?
---@param percent number
---@return string
function M.shade_color(color, percent)
  if not color then return "NONE" end
  local r, g, b = hex_to_rgb(color)
  if not r or not g or not b then return "NONE" end
  r, g, b = alter(r, percent), alter(g, percent), alter(b, percent)
  r, g, b = math.min(r, 255), math.min(g, 255), math.min(b, 255)
  return string.format("#%02x%02x%02x", r, g, b)
end

--- Determine whether to use black or white text
--- References:
--- 1. https://stackoverflow.com/a/1855903/837964
--- 2. https://stackoverflow.com/a/596243
function M.color_is_bright(hex)
  if not hex then return false end
  local r, g, b = hex_to_rgb(hex)
  -- If any of the colors are missing return false
  if not r or not g or not b then return false end
  -- Counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  return luminance > 0.5 -- if > 0.5 Bright colors, black font, otherwise Dark colors, white font
end

-- parses the gui hex color code (or cterm color number) from the given hl_name
--   color number (0-255) is returned if cterm is set to true in opts
--   if unable to parse, uses the fallback value
---@param opts table
---@return string? | number?
function M.get_color(opts)
  local name, attribute, fallback, not_match, cterm =
    opts.name, opts.attribute, opts.fallback, opts.not_match, opts.cterm
  -- translate from internal part to hl part
  assert(
    attribute == "fg" or attribute == "bg",
    fmt('attribute for %s should be one of "fg" or "bg", "%s" was passed in ', name, attribute)
  )
  attribute = attribute == "fg" and "foreground" or "background"

  -- try and get hl from name
  local success, hl = pcall(vim.api.nvim_get_hl_by_name, name, not cterm)
  if success and hl and hl[attribute] then
    if cterm then return hl[attribute] end
    -- convert from decimal color value to hex (e.g. 14257292 => "#D98C8C")
    local hex = "#" .. bit.tohex(hl[attribute], 6)
    if not not_match or not_match ~= hex then return hex end
  end
  -- note: in case of cterm, nvim_get_hl_by_name may return incorrect color
  --   numbers (but still < 256) for some highlight groups like TabLine,
  --   but return correct numbers for groups like DevIconPl. this problem
  --   does not happen for gui colors.

  -- no fallback for cterm colors
  if cterm then return nil end

  -- basic fallback
  if fallback and type(fallback) == "string" then return fallback end

  -- bit of recursive fallback logic
  if fallback and type(fallback) == "table" then
    assert(
      fallback.name and fallback.attribute,
      'Fallback should have "name" and "attribute" fields'
    )
    return M.get_color(fallback) -- allow chaining
  end

  -- we couldn't resolve the color
  return "NONE"
end

return M
