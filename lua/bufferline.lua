local vim = _G.vim
local api = vim.api
local highlight = '%#BufferLine#'
local tab_highlight = '%#BufferLineTab#'
local tab_selected_highlight = '%#BufferLineTabSelected#'
local selected_highlight = '%#BufferLineSelected#'
local diagnostic_highlight = '%#ErrorMsg#'
local background = '%#BufferLineBackground#'
local close = '%#BufferLine#%999X'
local padding = " "

local function safely_get_var(var)
  if pcall(function() api.nvim_get_var(var) end) then
    return api.nvim_get_var(var)
  else
    return nil
  end
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

local function contains(table, element)
  for key, _ in pairs(table) do
    if key == element then
      return true
    end
  end
  return false
end

local function table_size(T)
  local count = 0
  for _ in pairs(T) do count = count + 1 end
  return count
end

local function set_highlight(name, user_var)
  local dict = safely_get_var(user_var)
  if dict ~= nil and table_size(dict) > 0 then
    local cmd = "highlight! "..name
    if contains(dict, "gui") then
        cmd = cmd.." ".."gui="..dict.gui
    end
    if contains(dict, "guifg") then
        cmd = cmd.." ".."guifg="..dict.guifg
    end
    if contains(dict, "guibg") then
        cmd = cmd.." ".."guibg="..dict.guibg
    end
    if not pcall(api.nvim_command, cmd) then
      api.nvim_err_writeln(
        "Unable to set your highlights, something isn't configured correctly"
      )
    end
  end
end

local function colors()
  set_highlight('TabLineFill','bufferline_background')
  set_highlight('BufferLine', 'bufferline_buffer')
  set_highlight('BufferLineBackground','bufferline_buffer')
  set_highlight('BufferLineSelected','bufferline_selected')
  set_highlight('BufferLineTab', 'bufferline_tab')
  set_highlight('BufferLineTabSelected', 'bufferline_tab_selected')
end

local function handle_click(id)
  if id ~= nil then
    api.nvim_command('buffer '..id)
  end
end

local function make_clickable(item, buf_num)
  local is_clickable = api.nvim_call_function('has', {'tablineat'})
  if is_clickable then
    -- TODO: can the arbitrary function we pass be a lua func, if so HOW...
    -- Also handle clicking tabs
    return "%"..buf_num.."@nvim_bufferline#handle_click@"..item
  else
    return item
  end
end

local function create_buffer(line, path, buf_num, diagnostic_count)
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

  return line .."%X"
end

local function tab_click_component(num)
  return "%"..num.."T"
end

local function create_tab(num, is_active)
  local hl = is_active and tab_selected_highlight or tab_highlight
  return hl .. tab_click_component(num) .. padding.. num ..padding .. "%X"
end

local function get_tabs()
  local all_tabs = {}
  local tabs = api.nvim_list_tabpages()
  local current_tab = api.nvim_get_current_tabpage()

  for _,tab in ipairs(tabs) do
    local is_active_tab = current_tab == tab
    all_tabs[tab] = create_tab(tab, is_active_tab)
  end
  return all_tabs
end

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
local function is_valid(buffer)
  local listed = api.nvim_buf_get_option(buffer, "buflisted")
  local exists = api.nvim_buf_is_valid(buffer)
  return listed and exists
end

-- TODO
-- [X] Show tabs
-- [ ] Buffer label truncation
-- [ ] Handle keeping active buffer always in view
local function bufferline()
  local line = ""
  local tab_string = table.concat(get_tabs(), "")
  line = line..tab_string

  local buf_nums = api.nvim_list_bufs()
  for _,buf_id in pairs(buf_nums) do
    if is_valid(buf_id) then
      local name =  api.nvim_buf_get_name(buf_id)
      line = create_buffer(line, name, buf_id, 0)
    end
  end
  local close_icon = safely_get_var("bufferline_close_icon")
  close_icon = close_icon ~= nil and close_icon or " close "
  line = line..background
  line = line..padding
  line = line.."%="..close..close_icon
  return line
end

-- I'd ideally like to pass the preferences through on setup to go into the colors function
local function setup()
  nvim_create_augroups({
      BufferlineColors = {
        {"VimEnter", "*", [[lua require('bufferline').colors()]]};
        {"ColorScheme", "*", [[lua require('bufferline').colors()]]};
      }
    })
end

return {
  setup = setup,
  handle_click = handle_click,
  colors = colors,
  bufferline = bufferline,
}

