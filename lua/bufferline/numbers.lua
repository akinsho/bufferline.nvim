local constants = require("bufferline.constants")

---@class NumbersFuncOpts
---@field ordinal number
---@field id number
---@field lower number_helper
---@field raise number_helper

---@alias number_helper fun(num: number): string
---@alias numbers_func fun(opts: NumbersFuncOpts): string
---@alias numbers_opt '"superscript"' | '"subscript"' | '"both"' | numbers_func

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

--- convert single or multi-digit strings to {sub|super}script
---@param map table<string, string>
---@param num number
---@return string
local function construct_number(map, num)
  num = tostring(num)
  return num:gsub(".", function(c)
    return map[c] or ""
  end)
end

local function to_style(map)
  return function(num)
    return construct_number(map, num)
  end
end

local lower, raise = to_style(subscript_numbers), to_style(superscript_numbers)

---Add a number prefix to the buffer matching a user's preference
---@param buffer Buffer
---@param mode numbers_opt
---@param style string[]
---@return string
local function prefix(buffer, mode, style)
  if type(mode) == "function" then
    local ok, number = pcall(mode, {
      ordinal = buffer.ordinal,
      id = buffer.id,
      lower = lower,
      raise = raise,
    })
    if not ok then
      return ""
    end
    return number
  end
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
          .. construct_number(superscript_numbers, ordinal and buffer.ordinal or buffer.id)
      elseif s == "subscript" then
        num = num
          .. construct_number(subscript_numbers, ordinal and buffer.ordinal or buffer.id)
      else -- "none"
        num = num .. (v == "ordinal" and buffer.ordinal or buffer.id) .. "."
      end
    end

    return num
  else
    local n = mode == "ordinal" and buffer.ordinal or buffer.id
    local num = style == "superscript" and construct_number(superscript_numbers, n) or n .. "."
    return num
  end
end

--- @param context BufferContext
--- @return BufferContext
function M.component(context)
  local buffer = context.buffer
  local component = context.component
  local options = context.preferences.options
  local length = context.length
  if options.numbers == "none" then
    return context
  end
  local number_prefix = prefix(buffer, options.numbers, options.number_style)
  local number_component = number_prefix .. constants.padding
  component = number_component .. component
  length = length + vim.fn.strwidth(number_component)
  return context:update({ component = component, length = length })
end

return M
