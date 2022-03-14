local M = {}

local strwidth = vim.api.nvim_strwidth

M.current = {}

local valid = "abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ"

function M.reset()
  M.current = {}
end

---@param element Tabpage|Buffer
---@return string?
function M.get(element)
  local first_letter = element.name:sub(1, 1)
  -- should only match alphanumeric characters
  local invalid_char = first_letter:match("[^%w]")

  if not M.current[first_letter] and not invalid_char then
    M.current[first_letter] = element.id
    return first_letter
  end
  for letter in valid:gmatch(".") do
    if not M.current[letter] then
      M.current[letter] = element.id
      return letter
    end
  end
end

---@param ctx RenderContext
function M.component(ctx)
  local utils = require("bufferline.utils")
  local padding = require("bufferline.constants").padding
  local options = require("bufferline.config").get("options")

  local element = ctx.tab
  local length = ctx.length
  local component = ctx.component
  local hl = ctx.current_highlights
  local letter = element.letter

  if options.show_buffer_icons and element.icon then
    local right = string.rep(padding, math.ceil((strwidth(element.icon) - 1) / 2))
    local left = string.rep(padding, math.floor((strwidth(element.icon) - 1) / 2))
    letter = left .. element.letter .. right
  end

  component = utils.join(hl.pick, letter, padding, hl.background, component)
  length = utils.sum(length, strwidth(letter), strwidth(padding))
  return component, length
end

return M
