local api = vim.api

local M = {}

function M.to_rgb(color)
  local r = tonumber(string.sub(color, 2,3), 16)
  local g = tonumber(string.sub(color, 4,5), 16)
  local b = tonumber(string.sub(color, 6), 16)
  return r, g, b
end

-- SOURCE:
-- https://stackoverflow.com/questions/5560248/programmatically-lighten-or-darken-a-hex-color-or-rgb-and-blend-colors
function M.shade_color(color, percent)
  local r, g, b = M.to_rgb(color)

  -- If any of the colors are missing return "NONE" i.e. no highlight
  if not r or not g or not b then return "NONE" end

  r = math.floor(tonumber(r * (100 + percent) / 100))
  g = math.floor(tonumber(g * (100 + percent) / 100))
  b = math.floor(tonumber(b * (100 + percent) / 100))

  r = r < 255 and r or 255
  g = g < 255 and g or 255
  b = b < 255 and b or 255

  -- see:
  -- https://stackoverflow.com/questions/37796287/convert-decimal-to-hex-in-lua-4
  r = string.format("%x", r)
  g = string.format("%x", g)
  b = string.format("%x", b)

  local rr = string.len(r) == 1 and "0" .. r or r
  local gg = string.len(g) == 1 and "0" .. g or g
  local bb = string.len(b) == 1 and "0" .. b or b

  return "#"..rr..gg..bb
end

--- Determine whether to use black or white text
-- Ref: https://stackoverflow.com/a/1855903/837964
-- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
function M.color_is_bright(hex)
  if not hex then
    return false
  end
  local r, g, b = M.to_rgb(hex)
  -- If any of the colors are missing return false
  if not r or not g or not b then return false end
  -- Counting the perceptive luminance - human eye favors green color
  local luminance = (0.299*r + 0.587*g + 0.114*b)/255
  if luminance > 0.5 then
    return true -- Bright colors, black font
  else
    return false -- Dark colors, white font
  end
end

function M.get_hex(hl_name, part, fallback)
  if not fallback then fallback = "none" end
  local id = vim.fn.hlID(hl_name)
  local color = vim.fn.synIDattr(id, part)
  -- if we can't find the color we default to none
  if not color or color == "" then return fallback else return color end
end

local function table_size(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
  return count
end

function M.set_highlight(name, hl)
  if hl and table_size(hl) > 0 then
    local cmd = "highlight! "..name
    if hl.gui and hl.gui ~= "" then
      cmd = cmd.." ".."gui="..hl.gui
    end
    if hl.guifg and hl.guifg ~= "" then
      cmd = cmd.." ".."guifg="..hl.guifg
    end
    if hl.guibg and hl.guibg ~= "" then
      cmd = cmd.." ".."guibg="..hl.guibg
    end
    -- TODO using api here as it warns of an error if setting highlight fails
    local success, err = pcall(api.nvim_command, cmd)
    if not success then
      api.nvim_err_writeln(
        "Failed setting "..name.." highlight, something isn't configured correctly".."\n"..err
      )
    end
  end
end

return M
