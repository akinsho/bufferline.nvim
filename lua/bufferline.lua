local api = vim.api
local tabline_highlight = '%#TabLine#'
local tabline_fill = '%#TabLineFill#%T'
local tabline_close = '%=%#TabLine#%999X'

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

  local padding = " "
  local modified = api.nvim_buf_get_option(buf_num, 'modified')
  local file_name = api.nvim_call_function('fnamemodify', {path, ":p:t"})
  local devicons_loaded = api.nvim_call_function('exists', {'*WebDevIconsGetFileTypeSymbol'})
  line = line..padding..tabline_highlight

  -- parameters: a:1 (filename), a:2 (isDirectory)
  local icon = devicons_loaded and api.nvim_call_function('WebDevIconsGetFileTypeSymbol', {path}) or ""
  line = line..icon..padding..file_name..padding

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

local function bufferline()
  local buf_nums = api.nvim_list_bufs()
  local line = ""
  for _,v in pairs(buf_nums) do
    if is_valid(v) then
      local name =  api.nvim_buf_get_name(v)
      line = add_buffer(line, name, v)
    end
  end
  local icon = api.nvim_get_var("bufferline_close_icon")
  if icon == "" then
    icon = "close"
  end
  line = line..tabline_fill
  line = line..tabline_close..icon
  return line
end

bufferline()

return {
  bufferline = bufferline
}

