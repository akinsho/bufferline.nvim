local vim = _G.vim
local api = vim.api
local highlight = '%#BufferLine#'
local inactive_highlight = '%#BufferLineInactive#'
local tab_highlight = '%#BufferLineTab#'
local tab_selected_highlight = '%#BufferLineTabSelected#'
local selected_highlight = '%#BufferLineSelected#'
local diagnostic_highlight = '%#ErrorMsg#'
local background = '%#BufferLineBackground#'
local close = '%#BufferLine#%999X'
local padding = " "

---------------------------------------------------------------------------//
-- EXPORT
---------------------------------------------------------------------------//

local M = {}

---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//

local function safely_get_var(var)
  if pcall(function() api.nvim_get_var(var) end) then
    return api.nvim_get_var(var)
  else
    return nil
  end
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

local function _get_hex(hl_name, part)
  local id = api.nvim_call_function('hlID', {hl_name})
  return api.nvim_call_function('synIDattr', {id, part})
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

local function make_clickable(item, buf_num)
  local is_clickable = api.nvim_call_function('has', {'tablineat'})
  if is_clickable then
    -- TODO: can the arbitrary function we pass be a lua func, if so HOW...
    return "%"..buf_num.."@nvim_bufferline#handle_click@"..item
  else
    return item
  end
end

---------------------------------------------------------------------------//
-- CORE
---------------------------------------------------------------------------//
function M.handle_click(id)
  if id ~= nil then
    api.nvim_command('buffer '..id)
  end
end


function M.colors()
  set_highlight('TabLineFill','bufferline_background')
  set_highlight('BufferLine', 'bufferline_buffer')
  set_highlight('BufferLineInactive', 'bufferline_buffer_inactive')
  set_highlight('BufferLineBackground','bufferline_buffer')
  set_highlight('BufferLineSelected','bufferline_selected')
  set_highlight('BufferLineTab', 'bufferline_tab')
  set_highlight('BufferLineTabSelected', 'bufferline_tab_selected')
end

-- Borrowed this trick from
-- https://github.com/bagrat/vim-buffet/blob/28e8535766f1a48e6006dc70178985de2b8c026d/autoload/buffet.vim#L186
-- If the current buffer in the current window has a matching ID it is ours and so should
-- have the main selected highlighting. If it isn't but it is the window highlight it as inactive
-- the "trick" here is that "bufwinnr" retunrs a value which is the first window associated with a buffer
-- if there are no windows associated i.e. it is not in view and the function returns -1
local function get_buffer_highlight(buf_id)
  local current = api.nvim_call_function('winbufnr', {0}) == buf_id
  if current then
    return selected_highlight
  elseif api.nvim_call_function('bufwinnr', {buf_id}) > 0 then
    return inactive_highlight
  else
    return highlight
  end
end

local function create_buffer(path, buf_num, diagnostic_count)
  local buf_highlight = get_buffer_highlight(buf_num)

  if path == "" then
    path = "[No Name]"
  elseif string.find(path, 'term://') ~= nil then
    return buf_highlight..padding..' '..api.nvim_call_function('fnamemodify', {path, ":p:t"})..padding
  end

  local modified = api.nvim_buf_get_option(buf_num, 'modified')
  local file_name = api.nvim_call_function('fnamemodify', {path, ":p:t"})
  local devicons_loaded = api.nvim_call_function('exists', {'*WebDevIconsGetFileTypeSymbol'})

  -- parameters for devicons func: (filename), (isDirectory)
  local icon = devicons_loaded and api.nvim_call_function('WebDevIconsGetFileTypeSymbol', {path}) or ""
  local buffer = buf_highlight..padding..icon..padding..file_name..padding
  buffer = make_clickable(buffer, buf_num)

  if diagnostic_count > 0 then
    buffer = buffer..diagnostic_highlight..diagnostic_count..padding
  end

  if modified then
    local modified_icon = safely_get_var("bufferline_modified_icon")
    modified_icon = modified_icon ~= nil and modified_icon or "●"
    buffer = buffer..modified_icon..padding
  end

  return buffer .."%X"
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
-- [X] Fix current buffer highlight disappearing when inside ignored buffer
function M.bufferline()
  local line = ""
  local all_tabs = get_tabs()
  local tabs = all_tabs ~= nil and table.concat(all_tabs, "") or ""
  line = line..tabs

  local buf_nums = api.nvim_list_bufs()
  for _,buf_id in ipairs(buf_nums) do
    if is_valid(buf_id) then
      local name =  api.nvim_buf_get_name(buf_id)
      local buf = create_buffer(name, buf_id, 0)
      line = line .. buf
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
function M.setup()
  nvim_create_augroups({
      BufferlineColors = {
        {"VimEnter", "*", [[lua require('bufferline').colors()]]};
        {"ColorScheme", "*", [[lua require('bufferline').colors()]]};
      }
    })
end

return M
