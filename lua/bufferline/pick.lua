local lazy = require("bufferline.lazy")
local state = lazy.require("bufferline.state") ---@module "bufferline.state"
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"

local M = {}

local fn = vim.fn
local strwidth = vim.api.nvim_strwidth

M.current = {}

function M.reset() M.current = {} end

-- Prompts user to select a buffer then applies a function to the buffer
---@param func fun(id: number)
function M.choose_then(func)
  state.is_picking = true
  ui.refresh()
  -- NOTE: handle keyboard interrupts by catching any thrown errors
  local ok, char = pcall(fn.getchar)
  if ok then
    local letter = fn.nr2char(char)
    for _, item in ipairs(state.components) do
      local element = item:as_element()
      if element and letter == element.letter then func(element.id) end
    end
  end
  state.is_picking = false
  ui.refresh()
end

---@param element bufferline.Tab|bufferline.Buffer
---@return string?
function M.get(element)
  local valid_alphabet = config.options.pick.alphabet

  local first_letter = element.name:sub(1, 1)

  local is_valid_char = first_letter:match("[" .. valid_alphabet .. "]")

  if not M.current[first_letter] and is_valid_char then
    M.current[first_letter] = element.id
    return first_letter
  end
  for letter in valid_alphabet:gmatch(".") do
    if not M.current[letter] then
      M.current[letter] = element.id
      return letter
    end
  end
end

---@param ctx bufferline.RenderContext
---@return bufferline.Segment?
function M.component(ctx)
  local padding = require("bufferline.constants").padding

  local element = ctx.tab
  local hl = ctx.current_highlights
  local letter = element.letter

  if config.options.show_buffer_icons and element.icon then
    local right = string.rep(padding, math.ceil((strwidth(element.icon) - 1) / 2))
    local left = string.rep(padding, math.floor((strwidth(element.icon) - 1) / 2))
    letter = left .. element.letter .. right
  end
  return { text = letter, highlight = hl.pick }
end

return M
