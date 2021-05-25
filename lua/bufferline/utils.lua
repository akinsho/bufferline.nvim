---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
local M = {}

local fmt = string.format

function M.is_test()
  return _G.__TEST
end

function M.join(...)
  local t = ""
  for n = 1, select("#", ...) do
    local arg = select(n, ...)
    if type(arg) ~= "string" then
      arg = tostring(arg)
    end
    t = t .. arg
  end
  return t
end

-- return a new array containing the concatenation of all of its
-- parameters. Scalar parameters are included in place, and array
-- parameters have their values shallow-copied to the final array.
-- Note that userdata and function values are treated as scalar.
-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
function M.array_concat(...)
  local t = {}
  for n = 1, select("#", ...) do
    local arg = select(n, ...)
    if type(arg) == "table" then
      for _, v in ipairs(arg) do
        t[#t + 1] = v
      end
    else
      t[#t + 1] = arg
    end
  end
  return t
end

--- @param array table
--- @return table
function M.filter_duplicates(array)
  local seen = {}
  local res = {}

  for _, v in ipairs(array) do
    if not seen[v] then
      res[#res + 1] = v
      seen[v] = true
    end
  end
  return res
end

M.path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"

-- Source: https://teukka.tech/luanvim.html
function M.nvim_create_augroups(definitions)
  for group_name, definition in pairs(definitions) do
    vim.cmd("augroup " .. group_name)
    vim.cmd("autocmd!")
    for _, def in pairs(definition) do
      local command = table.concat(vim.tbl_flatten({ "autocmd", def }), " ")
      vim.cmd(command)
    end
    vim.cmd("augroup END")
  end
end

--- @param context table
function M.make_clickable(context)
  local mode = context.preferences.options.mode
  local component = context.component
  local buf_num = context.buffer.id
  if not vim.fn.has("tablineat") then
    return component
  end
  -- v:lua does not support function references in vimscript so
  -- the only way to implement this is using autoload viml functions
  local fn = mode == "multiwindow" and "handle_win_click" or "handle_click"
  return "%" .. buf_num .. "@nvim_bufferline#" .. fn .. "@" .. component
end

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
function M.is_valid(buf_num)
  if not buf_num or buf_num < 1 then
    return false
  end
  local exists = vim.api.nvim_buf_is_valid(buf_num)
  return vim.bo[buf_num].buflisted and exists
end

--- @param bufs table | nil
function M.get_valid_buffers(bufs)
  local buf_nums = bufs or vim.api.nvim_list_bufs()
  local valid_bufs = {}

  -- NOTE: In lua in order to iterate an array, indices should
  -- not contain gaps otherwise "ipairs" will stop at the first gap
  -- i.e the indices should be contiguous
  local count = 0
  for _, buf in ipairs(buf_nums) do
    if M.is_valid(buf) then
      count = count + 1
      valid_bufs[count] = buf
    end
  end
  return valid_bufs
end

---Print an error message to the commandline
---@param msg string
function M.echoerr(msg)
  M.echomsg(msg, "ErrorMsg")
end

---Print a message to the commandline
---@param msg string
---@param hl string?
function M.echomsg(msg, hl)
  hl = hl or "Title"
  vim.api.nvim_echo({ { fmt("[nvim-bufferline] %s", msg), hl } }, true, {})
end

return M
