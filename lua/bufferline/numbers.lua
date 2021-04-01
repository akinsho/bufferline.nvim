local constants = require "bufferline/constants"

local M = {}

local superscript_numbers = {
  [0] = "⁰",
  [1] = "¹",
  [2] = "²",
  [3] = "³",
  [4] = "⁴",
  [5] = "⁵",
  [6] = "⁶",
  [7] = "⁷",
  [8] = "⁸",
  [9] = "⁹",
  [10] = "¹⁰",
  [11] = "¹¹",
  [12] = "¹²",
  [13] = "¹³",
  [14] = "¹⁴",
  [15] = "¹⁵",
  [16] = "¹⁶",
  [17] = "¹⁷",
  [18] = "¹⁸",
  [19] = "¹⁹",
  [20] = "²⁰"
}

-- styled numbers at top half
local t_numbers = { ['0'] = "⁰", ['1'] = "¹", ['2'] = "²", ['3'] = "³", ['4'] = "⁴", ['5'] = "⁵", ['6'] = "⁶", ['7'] = "⁷", ['8'] = "⁸", ['9'] = "⁹" }
-- styled numbers at down half
local d_numbers = { ['0'] = '₀', ['1'] = '₁', ['2'] = '₂', ['3'] = '₃', ['4'] = '₄', ['5'] = '₅', ['6'] = '₆', ['7'] = '₇', ['8'] = '₈', ['9'] = '₉' }

-- from number to the styled number
local trans_number = function (t, n)
  local n = tostring(n)
  local r = ""
  for i = 1, #n do
    r = r .. t[n:sub(i,i)]
  end
  return r
end

local function prefix(buffer, mode, style)
  -- if mode is mix, it will be like lightline-bufferline, buffer_id at top left
  -- and ordinal number at bottom down, so the user can get the buffer number
  if mode == "mix" then
    return trans_number(t_numbers, buffer.id) .. trans_number(d_numbers, buffer.ordinal)
  else
    local n = mode == "ordinal" and buffer.ordinal or buffer.id
    local num = style == "superscript" and superscript_numbers[n] or n .. "."
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
