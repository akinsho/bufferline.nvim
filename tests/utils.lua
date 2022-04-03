local M = {}

local MockBuffer = {}

function MockBuffer:new(o)
  self.__index = self
  setmetatable(o, self)
  o.type = "buffer"
  return o
end

function MockBuffer:as_element()
  return self
end

M.MockBuffer = MockBuffer

local U = require("bufferline.utils")
local fn = vim.fn

local function strip_hls(str)
  return fn.substitute(str, "%#[a-zA-Z]*#", "", "g")
end

local function strip_click_command(str)
  return fn.substitute(str, "@[a-zA-Z|#|_]*@", "", "g")
end

local function strip_dangling_modifier(str)
  return fn.substitute(str, "%[[:alnum:]|=]*%*%", "", "g")
end

local function strip_modifier_digit(str)
  return fn.substitute(str, "%[[:digit:]*]*", "", "g")
end

local function strip_close(str)
  return fn.substitute(str, "999X", "", "g")
end

local function strip_parens(str)
  return fn.substitute(str, "[()]", "", "g")
end

---@param name string
---@param state BufferlineState
---@return TabElement
function M.find_buffer(name, state)
  for _, component in ipairs(state.components) do
    local element = component:as_element()
    if fn.matchstr(element.name, name) ~= "" then
      return component
    end
  end
end

---Remove special tabline syntax from bufferline in order to inspect its appearance
---@param str string
---@return string
function M.format_tabline(str)
  return U.compose(
    strip_hls,
    strip_click_command,
    strip_dangling_modifier,
    strip_modifier_digit,
    strip_close,
    strip_parens
  )(str)
end

return M
