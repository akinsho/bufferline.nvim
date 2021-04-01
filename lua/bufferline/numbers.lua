local constants = require "bufferline/constants"

local M = {}

local superscript_numbers = {
  ['0'] = "⁰",
  ['1'] = "¹",
  ['2'] = "²",
  ['3'] = "³",
  ['4'] = "⁴",
  ['5'] = "⁵",
  ['6'] = "⁶",
  ['7'] = "⁷",
  ['8'] = "⁸",
  ['9'] = "⁹",
}

local subscript_numbers = {
  ['0'] = '₀',
  ['1'] = '₁',
  ['2'] = '₂',
  ['3'] = '₃',
  ['4'] = '₄',
  ['5'] = '₅',
  ['6'] = '₆',
  ['7'] = '₇',
  ['8'] = '₈',
  ['9'] = '₉',
}

-- from number to the styled number
local convert_to_styled_num = function (t, n)
  local n = tostring(n)
  local r = ""
  for i = 1, #n do
    r = r .. t[n:sub(i,i)]
  end
  return r
end

local function prefix(buffer, mode, style)
  -- if mode is both, it will be like lightline-bufferline, buffer_id at top left
  -- and ordinal number at bottom down, so the user can get the buffer number
  if mode == "both" then
    if style == "superscript" then
      return convert_to_styled_num(superscript_numbers, buffer.id) .. convert_to_styled_num(subscript_numbers, buffer.ordinal)
    else
      return buffer.id .. "(" .. buffer.ordinal .. ")"
    end
  else
    local n = mode == "ordinal" and buffer.ordinal or buffer.id
    local num = style == "superscript" and convert_to_styled_num(superscript_numbers,n) or n .. "."
    return num
  end
end

--- @param context table
function M.component(context)
  local buffer = context.buffer
  local component = context.component
  local options = context.preferences.options
  local length = context.length
  if options.numbers == "none" then
    return component, length
  end
  local number_prefix = prefix(buffer, options.numbers, options.number_style)
  local number_component = number_prefix .. constants.padding
  component = number_component .. component
  length = length + vim.fn.strwidth(number_component)
  return component, length
end

return M
