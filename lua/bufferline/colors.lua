local M = {}

function M.to_rgb(color)
  local r = tonumber(string.sub(color, 2, 3), 16)
  local g = tonumber(string.sub(color, 4, 5), 16)
  local b = tonumber(string.sub(color, 6), 16)
  return r, g, b
end

--- SOURCE: https://stackoverflow.com/q/5560248
function M.shade_color(color, percent)
  local r, g, b = M.to_rgb(color)

  -- If any of the colors are missing return "NONE" i.e. no highlight
  if not r or not g or not b then
    return "NONE"
  end

  r = math.floor(tonumber(r * (100 + percent) / 100))
  g = math.floor(tonumber(g * (100 + percent) / 100))
  b = math.floor(tonumber(b * (100 + percent) / 100))

  r = r < 255 and r or 255
  g = g < 255 and g or 255
  b = b < 255 and b or 255

  -- see:
  -- https://stackoverflow.com/a/37797380
  r = string.format("%x", r)
  g = string.format("%x", g)
  b = string.format("%x", b)

  local rr = string.len(r) == 1 and "0" .. r or r
  local gg = string.len(g) == 1 and "0" .. g or g
  local bb = string.len(b) == 1 and "0" .. b or b

  return "#" .. rr .. gg .. bb
end

--- Determine whether to use black or white text
--- Ref:
--- 1. https://stackoverflow.com/a/1855903/837964
--- 2. https://stackoverflow.com/a/596243
function M.color_is_bright(hex)
  if not hex then
    return false
  end
  local r, g, b = M.to_rgb(hex)
  -- If any of the colors are missing return false
  if not r or not g or not b then
    return false
  end
  -- Counting the perceptive luminance - human eye favors green color
  local luminance = (0.299 * r + 0.587 * g + 0.114 * b) / 255
  if luminance > 0.5 then
    return true -- Bright colors, black font
  else
    return false -- Dark colors, white font
  end
end

-- parses the hex color code from the given hl_name
-- if unable to parse, uses the fallback value
---@param hl_name string
---@param part string
---@param fallback table
---@return string
function M.get_hex(hl_name, part, fallback)
  -- translate from internal part to hl part
  assert(part == "fg" or part == "bg", 'Color part should be one of "fg" or "bg"')
  part = part == "fg" and "foreground" or "background"

  -- try and get hl from name
  local success, hl = pcall(vim.api.nvim_get_hl_by_name, hl_name, true)
  if success and hl and hl[part] then
    -- convert from decimal color value to hex (e.g. 14257292 => "#D98C8C")
    return "#" .. bit.tohex(hl[part], 6)
  end

  -- basic fallback
  if fallback and type(fallback) == "string" then
    return fallback
  end

  -- bit of recursive fallback logic
  if fallback and type(fallback) == "table" then
    assert(
      fallback.name and fallback.attribute,
      'Fallback should have "name" and "attribute" fields'
    )
    return M.get_hex(fallback.name, fallback.attribute, fallback.fallback) -- allow chaining
  end

  -- we couldn't resolve the color
  return "NONE"
end

return M
