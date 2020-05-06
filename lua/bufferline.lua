local api = vim.api
local highlight = '%#BufferLine#'
local selected_highlight = '%#BufferLineSelected#'
local background = '%#BufferLineBackground#%T'
local close = '%=%#BufferLine#%999X'
local padding = " "

local function safely_get_var(var)
  if pcall(function() api.nvim_get_var(var) end) then
    return api.nvim_get_var(var)
  else
    return nil
  end
end

local function add_buffer(line, path, buf_num)
  if path == "" then
    path = "[No Name]"
  elseif string.find(path, 'term://') ~= nil then
    return ' '..api.nvim_call_function('fnamemodify', {path, ":p:t"})
  end

  local modified = api.nvim_buf_get_option(buf_num, 'modified')
  local file_name = api.nvim_call_function('fnamemodify', {path, ":p:t"})
  local is_current = api.nvim_get_current_buf() == buf_num
  local buf_highlight = is_current and selected_highlight or highlight
  local devicons_loaded = api.nvim_call_function('exists', {'*WebDevIconsGetFileTypeSymbol'})
  line = line..buf_highlight

  -- parameters: a:1 (filename), a:2 (isDirectory)
  local icon = devicons_loaded and api.nvim_call_function('WebDevIconsGetFileTypeSymbol', {path}) or ""
  line = padding .. line..padding..icon..padding..file_name..padding

  if modified then
    local modified_icon = safely_get_var("bufferline_modified_icon")
    modified_icon = modified_icon ~= nil and modified_icon or "●"
    line = line..modified_icon..padding
  end

  return line
end

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
local function is_valid(buffer)
  local listed = api.nvim_buf_get_option(buffer, "buflisted")
  local exists = api.nvim_buf_is_valid(buffer)
  return listed and exists
end

-- TODO
-- 1. Handle showing duplicate buffers if more than one tab is open
local function bufferline()
  local buf_nums = api.nvim_list_bufs()
  local line = ""
  for _,v in pairs(buf_nums) do
    if is_valid(v) then
      local name =  api.nvim_buf_get_name(v)
      line = add_buffer(line, name, v)
    end
  end
  local icon = safely_get_var("bufferline_close_icon")
  icon = icon ~= nil and icon or "close "
  line = line..background
  line = line..padding..close..icon
  return line
end

return {
  bufferline = bufferline
}

