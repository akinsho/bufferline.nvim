local config = require("bufferline.config")

---@class NumbersFuncOpts
---@field ordinal number
---@field id number
---@field lower number_helper
---@field raise number_helper

---@alias number_helper fun(num: number): string
---@alias numbers_func fun(opts: NumbersFuncOpts): string
---@alias numbers_opt '"buffer_id"' | '"ordinal"' | '"both"' | numbers_func

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

local maps = {
  superscript = superscript_numbers,
  subscript = subscript_numbers,
}

--- convert single or multi-digit strings to {sub|super}script
--- or return the plain number if there is no corresponding number table
---@param num number
---@param map table<string, string>?
---@return string
local function construct_number(num, map)
  if not map then return num .. "." end
  local str = tostring(num)
  local match = str:gsub(".", function(c) return map[c] or "" end)
  return match
end

local function to_style(map)
  return function(num) return construct_number(num, map) end
end

local lower, raise = to_style(subscript_numbers), to_style(superscript_numbers)

---Add a number prefix to the buffer matching a user's preference
---@param buffer TabElement
---@param numbers numbers_opt
---@return string
local function prefix(buffer, numbers)
  if type(numbers) == "function" then
    local ok, number = pcall(numbers, {
      ordinal = buffer.ordinal,
      id = buffer.id,
      lower = lower,
      raise = raise,
    })
    return ok and number or ""
  end
  -- if mode is both, numbers will look similar to lightline-bufferline,
  -- buffer_id at top left and ordinal number at bottom right
  if numbers == "both" then
    return construct_number(buffer.id) .. construct_number(buffer.ordinal, maps.subscript)
  end

  return construct_number(numbers == "ordinal" and buffer.ordinal or buffer.id)
end

--- @param context RenderContext
--- @return Segment?
function M.component(context)
  local element = context.tab
  local options = config.options
  if options.numbers == "none" then return end
  local number_prefix = prefix(element, options.numbers)
  if not number_prefix then return end
  return { highlight = context.current_highlights.numbers, text = number_prefix }
end

if require("bufferline.utils").is_test() then M.prefix = prefix end

return M
