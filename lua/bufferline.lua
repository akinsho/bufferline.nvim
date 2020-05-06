local api = vim.api
local tabline_highlight = '%#TabLine#'
local tabline_fill = '%#TabLineFill#%T'
local tabline_close = '%=%#TabLine#%999X'

local function add_buffer(line, path)
  if path == "" then
    path = "[No Name]"
  end
  local padding = " "
  local file_name = api.nvim_call_function('fnamemodify', {path, ":p:t"})
  local devicons_loaded = api.nvim_call_function('exists', {'*WebDevIconsGetFileTypeSymbol'})
  local icon = ""
  if devicons_loaded then
    -- parameters: a:1 (filename), a:2 (isDirectory)
    icon = api.nvim_call_function('WebDevIconsGetFileTypeSymbol', {path})
  end
  line = line..padding..tabline_highlight..icon..padding..file_name..padding
  return line
end

-- The provided api nvim_is_buf_loaded filters out
-- all hidden buffers
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
      line = add_buffer(line, name)
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

return {
  bufferline = bufferline
}

