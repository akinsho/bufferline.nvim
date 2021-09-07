local M = {}

local strwidth = vim.api.nvim_strwidth

M.current = {}

local valid = "abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ"

function M.reset()
  M.current = {}
end

---@param buf Buffer
---@return string?
function M.get(buf)
  local first_letter = buf.filename:sub(1, 1)
  -- should only match alphanumeric characters
  local invalid_char = first_letter:match("[^%w]")

  if not M.current[first_letter] and not invalid_char then
    M.current[first_letter] = buf.id
    return first_letter
  end
  for letter in valid:gmatch(".") do
    if not M.current[letter] then
      M.current[letter] = buf.id
      return letter
    end
  end
end

---@param ctx RenderContext
function M.component(ctx)
  local padding = require("bufferline.constants").padding
  local utils = require("bufferline.utils")

  local buffer = ctx.tab:as_buffer()
  local length = ctx.length
  local component = ctx.component
  local options = ctx.preferences.options
  local hl = ctx.current_highlights
  local letter = buffer.letter

  if options.show_buffer_icons and buffer.icon then
    local right = string.rep(padding, math.ceil((strwidth(buffer.icon) - 1) / 2))
    local left = string.rep(padding, math.floor((strwidth(buffer.icon) - 1) / 2))
    letter = left .. buffer.letter .. right
  end

  component = utils.join(hl.pick, letter, padding, hl.background, component)
  length = utils.sum(length, strwidth(letter), strwidth(padding))
  return component, length
end

return M
