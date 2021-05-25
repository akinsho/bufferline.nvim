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
  local r = ""
  for i = 1, #n do
    r = r .. t[n:sub(i, i)]
  end
  return r
end

local function prefix(buffer, mode, style)
  -- if mode is both, it numbers will look similar lightline-bufferline, buffer_id at top left
  -- and ordinal number at bottom right, so the user see the buffer number
  if mode == "both" then
    -- default number_style for mode "both"
    local both_style = { buffer_id = "none", ordinal = "subscript" }
    if style ~= "superscript" and type(style) == "table" then
      both_style.buffer_id = style[1] and style[1] or both_style.buffer_id
      both_style.ordinal = style[2] and style[2] or both_style.ordinal
    end

    local num = ""
    for _, v in ipairs({ "buffer_id", "ordinal" }) do
      local ordinal = v == "ordinal"
      local s = both_style[v] --  "superscript"| "subscript" | "none"
      if s == "superscript" then
        num = num
          .. convert_to_styled_num(superscript_numbers, ordinal and buffer.ordinal or buffer.id)
      elseif s == "subscript" then
        num = num
          .. convert_to_styled_num(subscript_numbers, ordinal and buffer.ordinal or buffer.id)
      else -- "none"
        num = num .. (v == "ordinal" and buffer.ordinal or buffer.id) .. "."
      end
    end

    return num
  else
    local n = mode == "ordinal" and buffer.ordinal or buffer.id
    local num = style == "superscript" and convert_to_styled_num(superscript_numbers, n) or n .. "."
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
