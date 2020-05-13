require 'buffers'

local api = vim.api

local highlight = '%#BufferLine#'
local inactive_highlight = '%#BufferLineInactive#'
local tab_highlight = '%#BufferLineTab#'
local tab_selected_highlight = '%#BufferLineTabSelected#'
local suffix_highlight = '%#BufferLine#'
local selected_highlight = '%#BufferLineSelected#'
local diagnostic_highlight = '%#ErrorMsg#'
local background = '%#BufferLineBackground#'
local separator_highlight = '%#BufferLineSeparator#'
local close = '%#BufferLine#%999X'
local padding = " "

---------------------------------------------------------------------------//
-- EXPORT
---------------------------------------------------------------------------//

local M = {}

---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
local function combine_lists(t1, t2)
  local result = {unpack(t1)}
  for i=1,#t2 do
    result[#result+1] = t2[i]
  end
  return result
end

local function safely_get_var(var)
  if pcall(function() api.nvim_get_var(var) end) then
    return api.nvim_get_var(var)
  else
    return nil
  end
end

local function get_plugin_variable(var, default)
  -- NOTE: in Nightly nvim you can use
  -- see: https://www.reddit.com/r/neovim/comments/gi8w8o/best_practice_lua_vimapinvim_get_var/
  -- var = "bufferline_"..var
  -- local user_var = vim.g[var]
  local user_var = safely_get_var("bufferline_"..var)
  return user_var or default
end

local function contains(table, element)
  for key, _ in pairs(table) do
    if key == element then
      return true
    end
  end
  return false
end

local function table_size(t)
  local count = 0
  for _ in pairs(t) do count = count + 1 end
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

-- SOURCE:
-- https://stackoverflow.com/questions/5560248/programmatically-lighten-or-darken-a-hex-color-or-rgb-and-blend-colors
local function shade_color(color, percent)
  local r = tonumber(string.sub(color, 2,3), 16)
  local g = tonumber(string.sub(color, 4,5), 16)
  local b = tonumber(string.sub(color, 6), 16)

  r = math.floor(tonumber(r * (100 + percent) / 100))
  g = math.floor(tonumber(g * (100 + percent) / 100))
  b = math.floor(tonumber(b * (100 + percent) / 100))

  r = r < 255 and r or 255
  g = g < 255 and g or 255
  b = b < 255 and b or 255

  -- see:
  -- https://stackoverflow.com/questions/37796287/convert-decimal-to-hex-in-lua-4
  r = string.format("%x", r)
  g = string.format("%x", g)
  b = string.format("%x", b)

  local rr = string.len(r) == 1 and "0" .. r or r
  local gg = string.len(g) == 1 and "0" .. g or g
  local bb = string.len(b) == 1 and "0" .. b or b

  return "#"..rr..gg..bb
end

local function get_hex(hl_name, part) -- luacheck: ignore
  local id = vim.fn.hlID(hl_name)
  return vim.fn.synIDattr(id, part)
end

local function set_highlight(name, hl)
-- TODO: if the value does not exist in the colorscheme this will return ""
-- which will fail in the set highlight function
  if hl and table_size(hl) > 0 then
    local cmd = "highlight! "..name
    if contains(hl, "gui") then
      cmd = cmd.." ".."gui="..hl.gui
    end
    if contains(hl, "guifg") then
      cmd = cmd.." ".."guifg="..hl.guifg
    end
    if contains(hl, "guibg") then
      cmd = cmd.." ".."guibg="..hl.guibg
    end
    local success, err = pcall(api.nvim_command, cmd)
    if not success then
      api.nvim_err_writeln(
        "Failed setting "..name.." highlight, something isn't configured correctly".."\n"..err
      )
    end
  end
end

local function make_clickable(item, buf_num)
  local is_clickable = vim.fn.has('tablineat')
  if is_clickable then
    -- TODO once v:lua is in stable neovim deprecate the autoload function
    if vim.fn.exists('v:lua') then
      return "%"..buf_num.."@v:lua.bufferline.handle_click@"..item
    else
      return "%"..buf_num.."@nvim_bufferline#handle_click@"..item
    end
  else
    return item
  end
end

---------------------------------------------------------------------------//
-- CORE
---------------------------------------------------------------------------//
function M.handle_click(id)
  if id then
    api.nvim_command('buffer '..id)
  end
end

local function get_buffer_highlight(buffer)
  if buffer:current() then
    return selected_highlight
  elseif buffer:visible() then
    return inactive_highlight
  else
    return highlight
  end
end

local function render_buffer(buffer, diagnostic_count)
  local buf_highlight = get_buffer_highlight(buffer)
  local length

  if string.find(buffer.path, 'term://') ~= nil then
    local name = vim.fn.fnamemodify(buffer.path, ":p:t")
    name = padding..' '..name..padding
    length = string.len(name)
    return buf_highlight..name, length
  end

  local component = padding..buffer.icon..padding..buffer.filename..padding
  -- Avoid including highlight strings in the buffer length
  length = string.len(component)
  component = buf_highlight..make_clickable(component, buffer.id)

  if diagnostic_count > 0 then
    local diagnostic_section = diagnostic_count..padding
    length = length + string.len(diagnostic_section)
    component = component..diagnostic_highlight..diagnostic_section
  end

  if buffer.modified then
    local modified_icon = get_plugin_variable("modified_icon", "●")
    local modified_section = modified_icon..padding
    length = length + string.len(modified_section)
    component = component..modified_section
  end

  -- Is rendering a space character "smaller" than a classic space possible
  -- http://jkorpela.fi/chars/spaces.html
  local separator_component = " "
  length = length + string.len(separator_component) * 2 -- we render 2 separators
  local separator = separator_highlight..separator_component.."%X"
  return separator..component .."%X", length
end

local function tab_click_component(num)
  return "%"..num.."T"
end

local function render_tab(num, is_active)
  local hl = is_active and tab_selected_highlight or tab_highlight
  local name = padding.. num ..padding
  local length = string.len(name)
  return hl .. tab_click_component(num) .. name .. "%X", length
end

local function get_tabs()
  local all_tabs = {}
  local tabs = api.nvim_list_tabpages()
  local current_tab = api.nvim_get_current_tabpage()

  for _,tab in ipairs(tabs) do
    local is_active_tab = current_tab == tab
    local component, length = render_tab(tab, is_active_tab)
    all_tabs[tab] = {component = component, length = length}
  end
  return all_tabs
end

local function render_close()
  local close_icon = get_plugin_variable("close_icon", " close ")
  return close_icon, string.len(close_icon)
end

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
local function is_valid(buffer)
  local listed = api.nvim_buf_get_option(buffer, "buflisted")
  local exists = api.nvim_buf_is_valid(buffer)
  return listed and exists
end

local function get_sections(buffers)
  local current = Buffers:new()
  local before = Buffers:new()
  local after = Buffers:new()

  for _,buf in ipairs(buffers) do
    if buf:current() then
      current:add(buf)
    -- We haven't reached the current buffer yet
    elseif current.length == 0 then
      before:add(buf)
    else
      after:add(buf)
    end
  end
  return before, current, after
end

--[[
PREREQUISITE: active buffer always remains in view
1. Find amount of available space in the window
2. Find the amount of space the bufferline will take up
3. If the bufferline will be too long remove one tab from the before or after
section
4. Re-check the size, if still too long truncate recursively till it fits
5. Add the number of truncated buffers as an indicator
--]]
local function truncate(before, current, after, available_width, marker)
  local line = ""
  local total_length = before.length + current.length + after.length
  if available_width >= total_length then
    -- Merge all the buffers and render the components
    local buffers = combine_lists(before.buffers, current.buffers)
    buffers = combine_lists(buffers, after.buffers)
    for _,buf in ipairs(buffers) do line = line .. buf.component end
    return line, marker
  else
    if before.length >= after.length then
      before:drop(1)
      marker.left_count = marker.left_count + 1
      marker.left = true
    else
      after:drop(#after.buffers)
      marker.right_count = marker.right_count + 1
      marker.right = true
    end
    return truncate(before, current, after, available_width, marker), marker
  end
end

local function render(buffers, tabs, close_length)
  local tab_components = ""
  local total_length = close_length

  -- Add the length of the tabs + close components to total length
  for _,t in pairs(tabs) do
    if not vim.tbl_isempty(t) then
      total_length = total_length + t.length
      tab_components = tab_components .. t.component
    end
  end

  local available_width = api.nvim_get_option("columns") - total_length
  local before, current, after = get_sections(buffers)
  local line, marker = truncate(
    before,
    current,
    after,
    available_width,
    { left_count = 0, right_count = 0, left = false, right = false}
    )

  if marker.left and marker.left_count > 0 then
    local trunc_icon = get_plugin_variable("left_trunc_marker", "⬅")
    line = suffix_highlight .. padding..marker.left_count..padding..trunc_icon..padding ..line
  end
  if marker.right and marker.right_count > 0 then
    local trunc_icon = get_plugin_variable("right_trunc_marker", "➡")
    line = line .. suffix_highlight .. padding..marker.right_count..padding..trunc_icon..padding
  end

  return tab_components..line
end

--[[
TODO
 [X] Show tabs

 [x] Handle keeping active buffer always in view
 https://github.com/weirongxu/coc-explorer/blob/59bd41f8fffdc871fbd77ac443548426bd31d2c3/src/icons.nerdfont.json#L2

 [x] Show remainder marker as <- or -> depending on where truncation occured

 [X] Fix current buffer highlight disappearing when inside ignored buffer

 [/] Refactor buffers to be a metatable with methods for sizing, and stringifying

 [x] Dynamically set styling to appear consistent across colorschemes

 [ ] Buffer label truncation

 [ ] Highlight file type icons if possible see:
--]]
function M.bufferline()
  local buf_nums = api.nvim_list_bufs()
  local buffers = {}
  local tabs = get_tabs()

  -- NOTE: In lua in order to iterate an array, indices should
  -- not contain gaps otherwise "ipairs" will stop at the first gap
  -- i.e the indices should be contiguous
  local count = 0
  for _,buf_id in ipairs(buf_nums) do
    if is_valid(buf_id) then
      count = count + 1
      local name =  api.nvim_buf_get_name(buf_id)
      local buf = Buffer:new {path = name, id = buf_id, ordinal = count}
      -- TODO: consider incorporating render_buffer into a buffer method
      -- ?? or should the data model be separate from highlighting concerns
      local component, length = render_buffer(buf, 0)
      buf.length = length
      buf.component = component
      buffers[count] = buf
    end
  end

  local close_component, close_length = render_close()
  local buffer_line = render(buffers, tabs, close_length)

  buffer_line = buffer_line..background
  buffer_line = buffer_line..padding
  buffer_line = buffer_line.."%="..close..close_component
  return buffer_line
end

-- Ideally this plugin should generate a beautiful statusline a little similar
-- to what you would get on other editors. The aim is that the default should
-- be so nice it's what anyone using this plugin sticks with. It should ideally
-- work across any well designed colorscheme deriving colors automagically.
local function get_defaults()
  local comment_fg = get_hex('Comment', 'fg')
  local normal_fg = get_hex('Normal', 'fg')
  local normal_bg = get_hex('Normal', 'bg')
  local tabline_sel_bg = get_hex('TabLineSel', 'bg')

  return {
    bufferline_tab = {
      guifg = comment_fg,
      guibg = normal_bg,
    };
    bufferline_tab_selected = {
      guifg = comment_fg,
      guibg = tabline_sel_bg,
    };
    bufferline_buffer = {
      guifg = comment_fg,
      guibg = shade_color(normal_bg, -30),
    };
    bufferline_buffer_inactive = {
      guifg = comment_fg,
      guibg = normal_bg,
    };
    bufferline_background = {
      guibg = shade_color(normal_bg, -20),
    };
    bufferline_separator = {
      guibg = shade_color(normal_bg, -32),
    };
    bufferline_selected = {
      guifg = normal_fg,
      guibg = normal_bg,
      gui = "bold,italic",
    };
  }
end

--[[ TODO pass the preferences through on setup to go into the colors function
 this way we can setup config vars in lua e.g.
 lua require('bufferline').setup({
  highlight = {
    inactive_highlight: '#mycolor'
  }
})
--]]
function M.setup(prefs)
  -- TODO: Validate user preferences and only set prefs that exists
  function _G.setup_bufferline_colors()
    local highlights = prefs or get_defaults()
    set_highlight('TabLineFill', highlights.bufferline_background)
    set_highlight('BufferLine', highlights.bufferline_buffer)
    set_highlight('BufferLineInactive', highlights.bufferline_buffer_inactive)
    set_highlight('BufferLineBackground',highlights.bufferline_buffer)
    set_highlight('BufferLineSelected',highlights.bufferline_selected)
    set_highlight('BufferLineTab', highlights.bufferline_tab)
    set_highlight('BufferLineSeparator', highlights.bufferline_separator)
    set_highlight('BufferLineTabSelected', highlights.bufferline_tab_selected)
  end
  nvim_create_augroups({
      BufferlineColors = {
        {"VimEnter", "*", [[lua setup_bufferline_colors()]]};
        {"ColorScheme", "*", [[lua setup_bufferline_colors()]]};
      }
    })
  api.nvim_set_option("showtabline", 2)
  api.nvim_set_option("tabline", [[%!luaeval("require'bufferline'.bufferline()")]])
end

return M
