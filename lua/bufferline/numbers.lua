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

local function prefix(buffer, mode, style)
  local n = mode == "ordinal" and buffer.ordinal or buffer.id
  local num = style == "superscript" and superscript_numbers[n] or n .. "."
  return num
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
