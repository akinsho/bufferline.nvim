local constants = require("bufferline/constants")

local M = {}

local superscript_numbers = {
  ["0"] = "⁰",
  ["1"] = "¹",
  ["2"] = "²",
  ["3"] = "³",
  ["4"] = "⁴",
  ["5"] = "⁵",
  ["6"] = "⁶",
  ["7"] = "⁷",
  ["8"] = "⁸",
  ["9"] = "⁹",
}

local subscript_numbers = {
  ["0"] = "₀",
  ["1"] = "₁",
  ["2"] = "₂",
  ["3"] = "₃",
  ["4"] = "₄",
  ["5"] = "₅",
  ["6"] = "₆",
  ["7"] = "₇",
  ["8"] = "₈",
  ["9"] = "₉",
}

-- from number to the styled number
local convert_to_styled_num = function(t, n)
  n = tostring(n)
  local str = ""
  for i = 1, #n do
    str = str .. t[n:sub(i, i)]
  end
  return str
end

-- build numbers string depending on config settings
local function prefix(buffer, mode, style)
  local str = "" -- a result that will be returned from the function
  local function str_append_with_style(number_style, number)
    if number_style == "superscript" then
      str = str .. convert_to_styled_num(superscript_numbers, number)
    elseif number_style == "subscript" then
      str = str .. convert_to_styled_num(subscript_numbers, number)
    else -- "none"
      str = str .. number
    end
  end
  -- if mode is "both" then by default numbers will look similar to lightline-bufferline
  -- with buffer_id at the top left and ordinal number at the bottom right,
  -- also conversely with "ordinal_first"
  if mode == "both" or mode == "ordinal_first" then
    -- trying to override default styles with user-defined
    local first_number_style, second_number_style = style, style
    if type(style) == "table" then first_number_style, second_number_style = style[1], style[2] end
    first_number_style, second_number_style = first_number_style or "none", second_number_style or "subscript"

    local numbers = mode == "ordinal_first" and { buffer.ordinal, buffer.id } or { buffer.id, buffer.ordinal }
    -- append the first number
    str_append_with_style(first_number_style, numbers[1])
    -- append some sensible styling after
    if first_number_style == "none" or first_number_style == "subscript" and second_number_style == "none" then
      str = str .. '.' -- makes numbers less confusing in this case
    elseif first_number_style == second_number_style then
      str = str .. ' ' -- adds space between numbers, so they don't look like one
    end
    -- append the second number
    str_append_with_style(second_number_style, numbers[2])
  else
    str_append_with_style(style, mode == "ordinal" and buffer.ordinal or buffer.id)
  end
  return str
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
