---@diagnostic disable: param-type-mismatch
local fn, api, map = vim.fn, vim.api, vim.keymap.set
local AUGROUP = api.nvim_create_augroup("BufferLineHover", { clear = true })

local delay = 500
local timer = nil
local previous_pos = nil

local M = {}

local function on_hover(current)
  if vim.o.laststatus == 0 then return end
  if current.screenrow == 1 then
    api.nvim_exec_autocmds("User", {
      pattern = "BufferLineHoverOver",
      data = { cursor_pos = current.screencol },
    })
  elseif previous_pos and previous_pos.screenrow == 1 and current.screenrow ~= 1 then
    api.nvim_exec_autocmds("User", {
      pattern = "BufferLineHoverOut",
      data = {},
    })
  end
  previous_pos = current
end

---@param conf BufferlineConfig
function M.setup(conf)
  if vim.version().minor < 8 or not vim.o.mousemoveevent then return end
  delay = vim.tbl_get(conf, "options", "hover", "delay") or delay

  map({ "", "i" }, "<MouseMove>", function()
    if timer then timer:close() end
    timer = vim.defer_fn(function()
      timer = nil
      on_hover(fn.getmousepos())
    end, delay)
    return "<MouseMove>"
  end, { expr = true })

  api.nvim_create_autocmd("VimLeavePre", {
    group = AUGROUP,
    callback = function()
      if timer then
        timer:close()
        timer = nil
      end
    end,
  })
end

return M
