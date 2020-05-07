local vim = _G.vim
local api = vim.api
local highlight = '%#BufferLine#'
local selected_highlight = '%#BufferLineSelected#'
local diagnostic_highlight = '%#ErrorMsg#'
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

local function coc_diagnostics()
  local result = {}
  local coc_exists = api.nvim_call_function("exists", {"*CocAction"})
  if not coc_exists then
    return result
  end

  local diagnostics = api.nvim_call_function("CocAction", {'diagnosticList'})
  if diagnostics == nil or diagnostics == "" then
    return result
  end

  for _,diagnostic in pairs(diagnostics) do
    local current_file = diagnostic.file
    if result[current_file] == nil then
      result[current_file] = {count = 1}
    else
      result[current_file].count = result[current_file].count + 1
    end
  end
  return result
end

local function get_diagnostic_count(diagnostics, path)
  return diagnostics[path] ~= nil and diagnostics[path].count or 0
end

-- Source: https://teukka.tech/luanvim.html
local function nvim_create_augroups(definitions)
  for group_name, definition in pairs(definitions) do
    api.nvim_command('augroup '..group_name)
    api.nvim_command('autocmd!')
    for _,def in pairs(definition) do
      local command = table.concat(vim.tbl_flatten{'autocmd', def}, ' ')
      api.nvim_command(command)
    end
    api.nvim_command('augroup END')
  end
end

local function get_hex(hl_name, part)
  local id = api.nvim_call_function('hlID', {hl_name})
  return api.nvim_call_function('synIDattr', {id, part})
end

-- This is a global so it can be called from our autocommands
function _G.colors()
  -- local default_colors = {
  --   gold         = '#F5F478',
  --   bright_blue  = '#A2E8F6',
  --   dark_blue    = '#4e88ff',
  --   dark_yellow  = '#d19a66',
  --   green        = '#98c379'
  -- }

  local comment_fg = get_hex('Comment', 'fg')
  local normal_bg = get_hex('Normal', 'bg')
  local normal_fg = get_hex('Normal', 'fg')

  -- TODO: fix hard coded colors
  api.nvim_command("highlight! TabLineFill guibg=#1b1e24")
  api.nvim_command("highlight! BufferLineBackground guibg=#1b1e24")
  api.nvim_command("highlight! BufferLine guifg="..comment_fg..' guibg=#1b1e24 gui=NONE')
  api.nvim_command('highlight! BufferLineSelected guifg='..normal_fg..' guibg='..normal_bg..' gui=bold,italic')

end

local function handle_click(id)
  if id ~= nil then
    api.nvim_command('buffer '..id)
  end
end

local function make_clickable(item, buf_num)
  local is_clickable = api.nvim_call_function('has', {'tablineat'})
  if is_clickable then
    -- TODO: can the arbitrary function we pass be a lua func
    -- if so HOW...
    return "%"..buf_num.."@nvim_bufferline#handle_click@"..item
  else
    return item
  end
end

local function add_buffer(line, path, buf_num, diagnostic_count)
  local is_current = api.nvim_get_current_buf() == buf_num
  local buf_highlight = is_current and selected_highlight or highlight

  if path == "" then
    path = "[No Name]"
  elseif string.find(path, 'term://') ~= nil then
    return buf_highlight..padding..' '..api.nvim_call_function('fnamemodify', {path, ":p:t"})..padding
  end

  local modified = api.nvim_buf_get_option(buf_num, 'modified')
  local file_name = api.nvim_call_function('fnamemodify', {path, ":p:t"})
  local devicons_loaded = api.nvim_call_function('exists', {'*WebDevIconsGetFileTypeSymbol'})
  line = line..buf_highlight

  -- parameters for devicons func: (filename), (isDirectory)
  local icon = devicons_loaded and api.nvim_call_function('WebDevIconsGetFileTypeSymbol', {path}) or ""
  local buffer = padding..icon..padding..file_name..padding
  local clickable_buffer = make_clickable(buffer, buf_num)
  line = padding..line..clickable_buffer

  if diagnostic_count > 0 then
    line = line..diagnostic_highlight..diagnostic_count..padding
  end

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
-- Show tabs
-- Buffer label truncation
-- Handle keeping active buffer always in view
local function bufferline()
  local line = ""
  local buf_nums = api.nvim_list_bufs()
  local diagnostics = coc_diagnostics()
  for _,buf_id in pairs(buf_nums) do
    if is_valid(buf_id) then
      local name =  api.nvim_buf_get_name(buf_id)
      local diagnostic_count = get_diagnostic_count(diagnostics, name)
      line = add_buffer(line, name, buf_id, diagnostic_count)
    end
  end
  local icon = safely_get_var("bufferline_close_icon")
  icon = icon ~= nil and icon or "close "
  line = line..background
  line = line..padding..close..icon
  return line
end

local function setup()
  nvim_create_augroups({
      BufferlineColors = {
        {"VimEnter", "*", [[lua colors()]]};
        {"ColorScheme", "*", [[lua colors()]]};
      }
    })
end

return {
  setup = setup,
  handle_click = handle_click,
  bufferline = bufferline,
}

