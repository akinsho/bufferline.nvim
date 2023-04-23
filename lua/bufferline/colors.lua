local M = {}

local api = vim.api

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
---see: https://stackoverflow.com/a/37797380
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
  return ("#%02x%02x%02x"):format(r, g, b)
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

-- TODO: remove when 0.9 is stable
local new_hl_api = api.nvim_get_hl ~= nil
local get_hl = function(name, use_cterm)
  if new_hl_api then
    local hl = api.nvim_get_hl(0, { name = name, link = false })
    if use_cterm then
      hl.fg, hl.bg = hl.ctermfg, hl.ctermbg
    end
    return hl
  end
  ---@diagnostic disable-next-line: undefined-field
  return api.nvim_get_hl_by_name(name, not use_cterm)
end

-- Map of nvim_get_hl() highlight attributes (new API) to
-- nvim_get_hl_by_name() highlight attributes (old API).
local hl_color_attrs = {
  fg = "foreground",
  bg = "background",
  sp = "special",
}

---@alias GetColorOpts { name: string, attribute: "fg" | "bg" | "sp", fallback: GetColorOpts?, not_match: string?, cterm: boolean? }
--- parses the GUI hex color code (or cterm color number) from the given hl_name
--- color number (0-255) is returned if cterm is set to true in opts
--- if unable to parse, uses the fallback value
---@param opts GetColorOpts
---@return string? | number?
function M.get_color(opts)
  local name, attribute, fallback, not_match, cterm =
    opts.name, opts.attribute, opts.fallback, opts.not_match, opts.cterm
  -- TODO: remove when 0.9 is stable
  if not new_hl_api then attribute = hl_color_attrs[attribute] end

  -- try and get hl from name
  local success, hl = pcall(get_hl, name, cterm)
  if success and hl and hl[attribute] then
    if cterm then return hl[attribute] end
    -- convert from decimal color value to hex (e.g. 14257292 => "#D98C8C")
    local hex = ("#%06x"):format(hl[attribute])
    if not not_match or not_match ~= hex then return hex end
  end
  --- NOTE: in case of cterm, nvim_get_hl_by_name may return incorrect color
  ---  numbers (but still < 256) for some highlight groups like TabLine,
  ---  but return correct numbers for groups like DevIconPl. this problem
  ---  does not happen for gui colors.

  if cterm then return end -- no fallback for cterm colors
  if fallback and type(fallback) == "string" then return fallback end -- basic fallback
  if fallback and type(fallback) == "table" then return M.get_color(fallback) end -- bit of recursive fallback logic, which allows chaining

  return "NONE" -- we couldn't resolve the color
end

return M
