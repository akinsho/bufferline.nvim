local constants = require("bufferline.constants")

---@class NumbersFuncOpts
---@field ordinal number
---@field id number
---@field lower number_helper
---@field raise number_helper

---@alias number_helper fun(num: number): string
---@alias numbers_func fun(opts: NumbersFuncOpts): string
---@alias numbers_opt '"buffer_id"' | '"ordinal"' | '"both"' | numbers_func

local M = {}

local styles = { "buffer_id", "ordinal" }

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
---@param map table<string, string>
---@param num number
---@return string
local function construct_number(map, num)
  if not map then
    return num .. "."
  end
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
---@param numbers numbers_opt
---@param numbers_style string[]
---@return string
local function prefix(buffer, numbers, numbers_style)
  if type(numbers) == "function" then
    local opts = {
      ordinal = buffer.ordinal,
      id = buffer.id,
      lower = lower,
      raise = raise,
    }
    local ok, number = pcall(numbers, opts)
    if not ok then
      return ""
    end
    return number
  end
  -- if mode is both, numbers will look similar to lightline-bufferline,
  -- buffer_id at top left and ordinal number at bottom right
  if numbers == "both" then
    -- default number_style for mode "both"
    local both = { buffer_id = "none", ordinal = "subscript" }
    if numbers_style ~= "superscript" and type(numbers_style) == "table" then
      both.buffer_id = numbers_style[1] and numbers_style[1] or both.buffer_id
      both.ordinal = numbers_style[2] and numbers_style[2] or both.ordinal
    end

    local num = ""
    for _, value in ipairs(styles) do
      local current = value == "ordinal" and buffer.ordinal or buffer.id
      num = num .. construct_number(maps[both[value]], current)
    end
    return num
  end

  local n = numbers == "ordinal" and buffer.ordinal or buffer.id
  local num = construct_number(maps[numbers_style], n)
  return num
end

--- @param context RenderContext
--- @return RenderContext
function M.component(context)
  local buffer = context.tab:as_buffer()
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

if require("bufferline.utils").is_test() then
  M.prefix = prefix
end

return M
