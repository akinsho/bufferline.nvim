---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
local lazy = require("bufferline.lazy")
--- @module "bufferline.constants"
local constants = lazy.require("bufferline.constants")
--- @module "bufferline.config"
local config = lazy.require("bufferline.config")

local M = {}

local fn, api = vim.fn, vim.api
local strwidth = api.nvim_strwidth

function M.is_test()
  ---@diagnostic disable-next-line: undefined-global
  return __TEST
end

---Takes a list of items and runs the callback
---on each updating the initial value
---@generic T
---@param accum T
---@param callback fun(accum:T, item: T, key: number|string): T
---@param list table<number|string, T>
---@return T
---@overload fun(callback: fun(accum: any, item: any, key: (number|string)), list: any[]): any
function M.fold(accum, callback, list)
  assert(accum and callback, "An initial value and callback must be passed to fold")
  if type(accum) == "function" and type(callback) == "table" then
    list = callback
    callback = accum
    accum = {}
  end
  for i, v in pairs(list) do
    accum = callback(accum, v, i)
  end
  return accum
end

---Variant of some that sums up the display size of characters
---@vararg string
---@return number
function M.measure(...)
  return M.fold(
    0,
    function(accum, item) return accum + api.nvim_strwidth(tostring(item)) end,
    { ... }
  )
end

---Concatenate a series of strings together
---@vararg string
---@return string
function M.join(...)
  return M.fold("", function(accum, item) return accum .. item end, { ... })
end

---@generic T
---@param callback fun(item: T, index: number): T
---@param list T[]
---@return T[]
function M.map(callback, list)
  local accum = {}
  for index, item in ipairs(list) do
    accum[index] = callback(item, index)
  end
  return accum
end

---@generic T
---@param list T[]
---@param callback fun(item: T): boolean
---@return T?
function M.find(callback, list)
  for _, v in ipairs(list) do
    if callback(v) then return v end
  end
end

-- return a new array containing the concatenation of all of its
-- parameters. Scalar parameters are included in place, and array
-- parameters have their values shallow-copied to the final array.
-- Note that userdata and function values are treated as scalar.
-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
--- @generic T
--- @vararg T
--- @return T
function M.merge_lists(...)
  local t = {}
  for n = 1, select("#", ...) do
    local arg = select(n, ...)
    if type(arg) == "table" then
      for _, v in pairs(arg) do
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
---@param matcher (fun(item: `T`):boolean)?
function M.for_each(callback, list, matcher)
  for _, item in ipairs(list) do
    if not matcher or matcher(item) then callback(item) end
  end
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

M.path_sep = vim.startswith(vim.loop.os_uname().sysname, "Windows") and "\\" or "/"

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
function M.is_valid(buf_num)
  if not buf_num or buf_num < 1 then return false end
  local exists = vim.api.nvim_buf_is_valid(buf_num)
  return vim.bo[buf_num].buflisted and exists
end

---@return number
function M.get_buf_count() return #fn.getbufinfo({ buflisted = 1 }) end

---@return number[]
---@diagnostic disable-next-line: return-type-mismatch
function M.get_valid_buffers() return vim.tbl_filter(M.is_valid, vim.api.nvim_list_bufs()) end

---@return number
function M.get_tab_count() return #fn.gettabinfo() end

function M.close_tab(tabhandle) vim.cmd("tabclose " .. api.nvim_tabpage_get_number(tabhandle)) end

--- Wrapper around `vim.notify` that adds message metadata
---@param msg string | string[]
---@param level "error" | "warn" | "info" | "debug" | "trace"
function M.notify(msg, level, opts)
  opts = opts or {}
  level = vim.log.levels[level:upper()]
  if type(msg) == "table" then msg = table.concat(msg, "\n") end
  local nopts = { title = "Bufferline" }
  if opts.once then return vim.schedule(function() vim.notify_once(msg, level, nopts) end) end
  vim.schedule(function() vim.notify(msg, level, nopts) end)
end

---@class GetIconOpts
---@field directory boolean
---@field path string
---@field extension string
---@field filetype string?

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
  if type == "terminal" then return webdev_icons.get_icon(type) end

  local use_default = config.options.show_buffer_default_icon

  local icon, hl
  if M.is_truthy(opts.filetype) then
    -- Don't use a default here so that we fall through to the next case if no icon is found
    icon, hl = webdev_icons.get_icon_by_filetype(opts.filetype, { default = false })
  end
  if not icon then
    icon, hl = webdev_icons.get_icon(fn.fnamemodify(opts.path, ":t"), opts.extension, {
      default = use_default,
    })
  end

  if not icon then return "", "" end
  return icon, hl
end

local current_stable = {
  major = 0,
  minor = 7,
  patch = 0,
}

function M.is_current_stable_release() return vim.version().minor >= current_stable.minor end

-- truncate a string based on number of display columns/cells it occupies
-- so that multibyte characters are not broken up mid character
---@param str string
---@param col_limit number
---@return string
local function truncate_by_cell(str, col_limit)
  if str and str:len() == api.nvim_strwidth(str) then return fn.strcharpart(str, 0, col_limit) end
  local short = fn.strcharpart(str, 0, col_limit)
  local width = api.nvim_strwidth(short)
  while width > 1 and width > col_limit do
    short = fn.strcharpart(short, 0, fn.strchars(short) - 1)
    width = api.nvim_strwidth(short)
  end
  return short
end

--- Truncate a name being mindful of multibyte characters and append an ellipsis
---@param name string
---@param word_limit number
---@return string
function M.truncate_name(name, word_limit)
  if strwidth(name) <= word_limit then return name end
  -- truncate nicely by seeing if we can drop the extension first
  -- to make things fit if not then truncate abruptly
  local ext = fn.fnamemodify(name, ":e")
  if ext ~= "" then
    local truncated = name:gsub("%." .. ext, "", 1)
    if api.nvim_strwidth(truncated) < word_limit then return truncated .. constants.ELLIPSIS end
  end
  return truncate_by_cell(name, word_limit - 1) .. constants.ELLIPSIS
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
