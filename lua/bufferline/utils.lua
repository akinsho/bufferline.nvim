---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
local lazy = require("bufferline.lazy")
--- @module "bufferline.constants"
local constants = lazy.require("bufferline.constants")
--- @module "bufferline.config"
local config = lazy.require("bufferline.config")

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
  return config.options.debug.logging
end

---@param msg string
function M.log.debug(msg)
  if check_logging() then
    local info = debug.getinfo(2, "S")
    vim.schedule(function()
      M.notify(
        fmt("[bufferline]: %s\n%s:%s", msg, info.linedefined, info.short_src),
        M.D,
        { once = true }
      )
    end)
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

---@return number
function M.get_buf_count()
  return #fn.getbufinfo({ buflisted = 1 })
end

---@return number[]
function M.get_valid_buffers()
  return vim.tbl_filter(M.is_valid, vim.api.nvim_list_bufs())
end

---@return number
function M.get_tab_count()
  return #fn.gettabinfo()
end

M.W = vim.log.levels.WARN
M.E = vim.log.levels.ERROR
M.I = vim.log.levels.INFO
M.D = vim.log.levels.DEBUG

--- Wrapper around `vim.notify` that adds message metadata
---@param msg string
---@param level number
function M.notify(msg, level, opts)
  opts = opts or {}
  local nopts = { title = "Bufferline" }
  if opts.once then
    return vim.notify_once(msg, level, nopts)
  end
  vim.notify(msg, level, nopts)
end

---@class GetIconOpts
---@field directory boolean
---@field path string
---@field extension string

---Get an icon for a filetype using either nvim-web-devicons or vim-devicons
---if using the lua plugin this also returns the icon's highlights
---@param opts GetIconOpts
---@return string, string?
function M.get_icon(opts)
  local loaded, webdev_icons = pcall(require, "nvim-web-devicons")
  if opts.directory then
    local hl = loaded and "DevIconDefault" or nil
    return constants.FOLDER_ICON, hl
  end
  if not loaded then
    if fn.exists("*WebDevIconsGetFileTypeSymbol") > 0 then
      return fn.WebDevIconsGetFileTypeSymbol(opts.path), ""
    end
    return "", ""
  end
  if type == "terminal" then
    return webdev_icons.get_icon(type)
  end
  local name = fn.fnamemodify(opts.path, ":t")
  local icon, hl = webdev_icons.get_icon(name, opts.extension, {
    default = config.options.show_buffer_default_icon,
  })
  if not icon then
    return "", ""
  end
  return icon, hl
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

function M.truncate_name(name, word_limit)
  local trunc_symbol = "…"
  if api.nvim_strwidth(name) <= word_limit then
    return name
  end
  -- truncate nicely by seeing if we can drop the extension first
  -- to make things fit if not then truncate abruptly
  local without_prefix = fn.fnamemodify(name, ":t:r")
  if api.nvim_strwidth(without_prefix) < word_limit then
    return without_prefix .. trunc_symbol
  end
  return truncate_by_cell(name, word_limit - 1) .. trunc_symbol
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
