local lazy = require("bufferline.lazy")
local state = lazy.require("bufferline.state") ---@module "bufferline.state"
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"

local M = {}

local fn = vim.fn
local strwidth = vim.api.nvim_strwidth

M.current = {}

local valid = "abcdefghijklmopqrstuvwxyzABCDEFGHIJKLMOPQRSTUVWXYZ"

function M.reset() M.current = {} end

local buffer_sets_file = vim.fn.stdpath("data") .. "/" .. "bufferline-buffer-sets.json"
M.buffer_sets = vim.fn.filereadable(buffer_sets_file) ~= 0 and vim.fn.json_decode(vim.fn.readfile(buffer_sets_file)) or {}

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

function M.write_buffer_sets()
  vim.schedule(function ()
    local json = vim.fn.json_encode(M.buffer_sets)
    vim.fn.writefile({json}, buffer_sets_file)
  end)
end

---@param element bufferline.Buffer
---@return string?
function M.get(element)
  local cwd = vim.loop.cwd()
  local set = M.buffer_sets[cwd] or {}
  if not M.buffer_sets[cwd] then
    M.buffer_sets[cwd] = set
  end

  if set[element.path] then
    return set[element.path]
  end

  -- this buffer has not yet been assigned a letter for the current buffer set

  local other_sets = {}
  local other_sets_merged = set
  local possible_letter
  for other_cwd, other_set in pairs(M.buffer_sets) do
    if other_cwd == cwd then goto continue end
    local letter = other_set[element.path]
    if letter then
      other_sets[other_cwd] = other_set
      -- NOTE: we assume (and must maintain) that any previously assigned letters for this buffer are the same across buffer sets
      possible_letter = letter
      other_sets_merged = vim.tbl_extend("keep", other_sets_merged, other_set)
    end
    ::continue::
  end

  if possible_letter then
    for _, letter in pairs(set) do
      if possible_letter == letter then
        possible_letter = nil -- already taken in this set, must re-assign (in all buffer sets)
        break
      end
    end

    if possible_letter then -- OK to use same letter for this set
      set[element.path] = possible_letter
      M.write_buffer_sets()
      return possible_letter
    end
  end

  -- either buffer never previously assigned or possible_letter already taken in this set, must re-assign (in all buffer sets)

  local letter_order = {}
  for c in element.name:lower():gmatch("%w") do table.insert(letter_order, c) end
  for c in valid:gmatch(".") do table.insert(letter_order, c) end

  local other_sets_merged_inverse = {} -- (for efficiency)
  for file, letter in pairs(other_sets_merged) do
    other_sets_merged_inverse[letter] = file
  end

  for _, letter in ipairs(letter_order) do
    if not other_sets_merged_inverse[letter] then -- letter must not conflict with any other sets FIXME ignore nonexistent files (useful in case of moving a project's directory)
      for _, other_set in pairs(other_sets) do
        other_set[element.path] = letter
      end
      set[element.path] = letter
      M.write_buffer_sets()
      return letter
    end
  end
end

---@param element bufferline.Tab
---@return string?
function M.get_tab(element)
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
