---@diagnostic disable: param-type-mismatch
local lazy = require("bufferline.lazy")
local state = lazy.require("bufferline.state") ---@module "bufferline.state"
local ui = lazy.require("bufferline.ui") ---@module "bufferline.ui"
local config = lazy.require("bufferline.config") ---@module "bufferline.config"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"

local fn, map = vim.fn, vim.keymap.set

local M = {}

--- Shift the visible window of the bufferline without changing the active buffer.
--- @param direction -1|1 -1 scrolls towards the start of the list, 1 towards the end
local function on_scroll(direction)
  local opts = config.options.mouse_scroll or {}
  local step = opts.step or 1

  local cur
  if state.scroll_offset ~= nil then
    cur = state.scroll_offset
  else
    -- entering scroll mode: seed from where the auto (centred) view currently starts and
    -- remember the active element + list size so we know when to snap back to auto mode
    cur = state.scroll_pivot_hint or 0
    local element = state.components and state.components[state.current_element_index]
    state.set({
      scroll_current_id = element and element.id or vim.NIL,
      scroll_count = state.components and #state.components or 0,
    })
  end

  -- lower clamp here; the upper clamp is applied render-side against the available width
  state.set({ scroll_offset = math.max(0, cur + direction * step) })
  ui.refresh()
end

--- Build an expr-map callback that only acts when the mouse is over the tabline (screenrow 1),
--- otherwise it returns the original key so scrolling over normal windows is unaffected.
--- @param direction -1|1
--- @param key string the original wheel key to fall through to
local function handler(direction, key)
  return function()
    if vim.o.showtabline == 0 then return key end
    local ok, pos = pcall(fn.getmousepos)
    if ok and pos.screenrow == 1 then
      on_scroll(direction)
      return ""
    end
    return key
  end
end

---@param conf bufferline.Config
function M.setup(conf)
  local opts = conf.options.mouse_scroll
  if not opts or not opts.enabled then return end

  -- both vertical and horizontal wheels drive horizontal movement; up/left = towards the start
  map({ "", "i" }, "<ScrollWheelUp>", handler(-1, "<ScrollWheelUp>"), { expr = true })
  map({ "", "i" }, "<ScrollWheelDown>", handler(1, "<ScrollWheelDown>"), { expr = true })
  map({ "", "i" }, "<ScrollWheelLeft>", handler(-1, "<ScrollWheelLeft>"), { expr = true })
  map({ "", "i" }, "<ScrollWheelRight>", handler(1, "<ScrollWheelRight>"), { expr = true })
end

if utils.is_test() then M.on_scroll = on_scroll end

return M
