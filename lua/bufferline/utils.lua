---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
local M = { log = {} }

local fmt = string.format
local fn = vim.fn
local api = vim.api

function M.is_test()
  ---@diagnostic disable-next-line: undefined-global
  return __TEST
end

---@return boolean
local function check_logging()
  ---@type BufferlineOptions
  local config = require("bufferline.config").get("options")
  return config.debug.logging
end

---@param msg string
function M.log.debug(msg)
  if check_logging() then
    local info = debug.getinfo(2, "S")
    print(fmt("[bufferline]: %s\n%s\n%s", msg, info.linedefined, info.short_src))
  end
end

---Takes all args and passes them on untouched
---@generic A
---@return A
function M.identity(...)
  return ...
end

---Takes a list of items and runs the callback
---on each updating the initial value
---@generic T
---@param accum T
---@param callback fun(accum:T, item: T, index: number): T
---@param list T[]
---@return T
function M.fold(accum, callback, list)
  assert(accum and callback, "An initial value and callback must be passed to fold")
  for i, v in ipairs(list) do
    accum = callback(accum, v, i)
  end
  return accum
end

---Add a series of numbers together
---@vararg number
---@return number
function M.sum(...)
  return M.fold(0, function(accum, item)
    return accum + item
  end, { ... })
end

---Variant of some that sums up the display size of characters
---@vararg string
---@return number
function M.measure(...)
  return M.fold(0, function(accum, item)
    return accum + api.nvim_strwidth(item)
  end, { ... })
end

---Concatenate a series of strings together
---@vararg string
---@return string
function M.join(...)
  return M.fold("", function(accum, item)
    return accum .. item
  end, { ... })
end

---@generic T
---@param callback fun(item: T): T
---@param list T[]
---@return T[]
function M.map(callback, list)
  return M.fold({}, function(accum, item)
    table.insert(accum, callback(item))
    return accum
  end, list)
end

---@generic T
---@param list T[]
---@param callback fun(item: T): boolean
---@return T
function M.find(list, callback)
  for _, v in ipairs(list) do
    if callback(v) then
      return v
    end
  end
end

--- A function which takes n number of functions and
--- passes the result of each function to the next
---@generic T
---@return fun(args: T): T
function M.compose(...)
  local funcs = { ... }
  local function recurse(i, ...)
    if i == #funcs then
      return funcs[i](...)
    end
    return recurse(i + 1, funcs[i](...))
  end
  return function(...)
    return recurse(1, ...)
  end
end

-- return a new array containing the concatenation of all of its
-- parameters. Scalar parameters are included in place, and array
-- parameters have their values shallow-copied to the final array.
-- Note that userdata and function values are treated as scalar.
-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
--- @generic T
--- @vararg any
--- @return T[]
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

---Execute a callback for each item or only those that match if a matcher is passed
---@generic T
---@param list T[]
---@param callback fun(item: `T`)
---@param matcher fun(item: `T`):boolean
function M.for_each(list, callback, matcher)
  for _, item in ipairs(list) do
    if not matcher or matcher(item) then
      callback(item)
    end
  end
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

--- creates a table whose keys are tbl's values and the value of these keys
--- is their key in tbl (similar to vim.tbl_add_reverse_lookup)
--- this assumes that the values in tbl are unique and hashable (no nil/NaN)
--- @generic K,V
--- @param tbl table<K,V>
--- @return table<V,K>
function M.tbl_reverse_lookup(tbl)
  local ret = {}
  for k, v in pairs(tbl) do
    ret[v] = k
  end
  return ret
end

M.path_sep = vim.loop.os_uname().sysname == "Windows" and "\\" or "/"

-- Source: https://teukka.tech/luanvim.html
function M.augroup(definitions)
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

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
function M.is_valid(buf_num)
  if not buf_num or buf_num < 1 then
    return false
  end
  local exists = vim.api.nvim_buf_is_valid(buf_num)
  return vim.bo[buf_num].buflisted and exists
end

---@return number[]
function M.get_valid_buffers()
  local buf_nums = vim.api.nvim_list_bufs()
  local ids = {}
  for _, buf in ipairs(buf_nums) do
    if M.is_valid(buf) then
      ids[#ids + 1] = buf
    end
  end
  return ids
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
  vim.api.nvim_echo({ { fmt("[bufferline] %s", msg), hl } }, true, {})
end

---Get an icon for a filetype using either nvim-web-devicons or vim-devicons
---if using the lua plugin this also returns the icon's highlights
---@param buf Buffer
---@param is_directory boolean
---@return string, string?
function M.get_icon(buf, is_directory)
  local loaded, webdev_icons = pcall(require, "nvim-web-devicons")
  if is_directory then
    local hl = loaded and "DevIconDefault" or nil
    return "", hl
  end
  if buf.buftype == "terminal" then
    -- NOTE: use an explicit if statement so both values from get icon can be returned
    -- this does not work if a ternary is used instead as only a single value is returned
    if not loaded then
      return ""
    end
    return webdev_icons.get_icon(buf.buftype)
  end
  if loaded then
    return webdev_icons.get_icon(fn.fnamemodify(buf.path, ":t"), buf.extension, { default = true })
  end
  local devicons_loaded = fn.exists("*WebDevIconsGetFileTypeSymbol") > 0
  return devicons_loaded and fn.WebDevIconsGetFileTypeSymbol(buf.path) or ""
end

---Add click action to a component
---@param func_name string
---@param id number
---@param component string
---@return string
function M.make_clickable(func_name, id, component)
  -- v:lua does not support function references in vimscript so
  -- the only way to implement this is using autoload vimscript functions
  return "%" .. id .. "@nvim_bufferline#" .. func_name .. "@" .. component
end

-- truncate a string based on number of display columns/cells it occupies
-- so that multibyte characters are not broken up mid character
---@param str string
---@param col_limit number
---@return string
local function truncate_by_cell(str, col_limit)
  if str and str:len() == api.nvim_strwidth(str) then
    return fn.strcharpart(str, 0, col_limit)
  end
  local short = fn.strcharpart(str, 0, col_limit)
  if api.nvim_strwidth(short) > col_limit then
    while api.nvim_strwidth(short) > col_limit do
      short = fn.strcharpart(short, 0, fn.strchars(short) - 1)
    end
  end
  return short
end

function M.truncate_filename(filename, word_limit)
  local trunc_symbol = "…"
  if api.nvim_strwidth(filename) <= word_limit then
    return filename
  end
  -- truncate nicely by seeing if we can drop the extension first
  -- to make things fit if not then truncate abruptly
  local without_prefix = fn.fnamemodify(filename, ":t:r")
  if api.nvim_strwidth(without_prefix) < word_limit then
    return without_prefix .. trunc_symbol
  end
  return truncate_by_cell(filename, word_limit - 1) .. trunc_symbol
end

function M.is_truthy(value)
  return value ~= nil
    and value ~= false
    and value ~= 0
    and value ~= ""
    and value ~= "0"
    and value ~= "false"
    and value ~= "nil"
end

return M
