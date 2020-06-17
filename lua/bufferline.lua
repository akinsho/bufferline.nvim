require 'buffers'
local colors = require 'colors'

local api = vim.api
local strwidth = vim.fn.strwidth

---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local highlight = '%#BufferLine#'
local inactive_highlight = '%#BufferLineInactive#'
local tab_highlight = '%#BufferLineTab#'
local tab_selected_highlight = '%#BufferLineTabSelected#'
local suffix_highlight = '%#BufferLine#'
local selected_highlight = '%#BufferLineSelected#'
local indicator_highlight = '%#BufferLineSelectedIndicator#'
local modified_highlight = '%#BufferLineModified#'
local modified_inactive_highlight = '%#BufferLineModifiedInactive#'
local modified_selected_highlight = '%#BufferLineModifiedSelected#'
local diagnostic_highlight = '%#ErrorMsg#'
local background = '%#BufferLineBackground#'
local separator_highlight = '%#BufferLineSeparator#'
local close = '%#BufferLineTabClose#%999X'

---------------------------------------------------------------------------//
-- Constants
---------------------------------------------------------------------------//
local padding = " "

local superscript_numbers = {
  [0] = '⁰',
  [1] = '¹',
  [2] = '²',
  [3] = '³',
  [4] = '⁴',
  [5] = '⁵',
  [6] = '⁶',
  [7] = '⁷',
  [8] = '⁸',
  [9] = '⁹',
  [10] = '¹⁰',
  [11] = '¹¹',
  [12] = '¹²',
  [13] = '¹³',
  [14] = '¹⁴',
  [15] = '¹⁵',
  [16] = '¹⁶',
  [17] = '¹⁷',
  [18] = '¹⁸',
  [19] = '¹⁹',
  [20] = '²⁰'
}
-------------------------------------------------------------------------//
-- EXPORT
---------------------------------------------------------------------------//

local M = {
  shade_color = colors.shade_color
}

---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
-- https://stackoverflow.com/questions/1283388/lua-merge-tables
local function deep_merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            deep_merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end
-- return a new array containing the concatenation of all of its
-- parameters. Scaler parameters are included in place, and array
-- parameters have their values shallow-copied to the final array.
-- Note that userdata and function values are treated as scalar.
-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
local function array_concat(...)
    local t = {}
    for n = 1,select("#",...) do
        local arg = select(n,...)
        if type(arg) == "table" then
            for _,v in ipairs(arg) do
                t[#t+1] = v
            end
        else
            t[#t+1] = arg
        end
    end
    return t
end

local function get_plugin_variable(var, default)
  var = "bufferline_"..var
  local user_var = vim.g[var]
  return user_var or default
end

-- Source: https://teukka.tech/luanvim.html
local function nvim_create_augroups(definitions)
  for group_name, definition in pairs(definitions) do
    vim.cmd('augroup '..group_name)
    vim.cmd('autocmd!')
    for _,def in pairs(definition) do
      local command = table.concat(vim.tbl_flatten{'autocmd', def}, ' ')
      vim.cmd(command)
    end
    vim.cmd('augroup END')
  end
end

--- @param mode string | nil
--- @param item string
--- @param buf_num number
local function make_clickable(mode, item, buf_num)
  if not vim.fn.has('tablineat') then return item end
  -- v:lua does not support function references in vimscript so
  -- the only way to implement this is using autoload viml functions
  if mode == "multiwindow" then
    return "%"..buf_num.."@nvim_bufferline#handle_win_click@"..item
  else
    return "%"..buf_num.."@nvim_bufferline#handle_click@"..item
  end
end

-- @param buf_id number
local function close_button(buf_id)
  local symbol = "✕"..padding
  local size = strwidth(symbol)
  return "%" .. buf_id .. "@nvim_bufferline#handle_close_buffer@".. symbol, size
end
---------------------------------------------------------------------------//
-- CORE
---------------------------------------------------------------------------//
function M.handle_close_buffer(buf_id)
  vim.cmd("bdelete ".. buf_id)
end

function M.handle_win_click(id)
  local win_id = vim.fn.bufwinid(id)
  vim.fn.win_gotoid(win_id)
end

function M.handle_click(id)
  if id then
    vim.cmd('buffer '..id)
  end
end

local function get_buffer_highlight(buffer)
  if buffer:current() then
    return selected_highlight, modified_selected_highlight
  elseif buffer:visible() then
    return inactive_highlight, modified_inactive_highlight
  else
    return highlight, modified_highlight
  end
end

local function get_number_prefix(buffer, mode, style)
  local n = mode == "ordinal" and buffer.ordinal or buffer.id
  local num = style == "superscript" and superscript_numbers[n] or n .. "."
  return num
end

local function truncate_filename(filename, word_limit)
  local trunc_symbol = '…' -- '...'
  local too_long = string.len(filename) > word_limit
  return too_long and string.sub(filename, 0, word_limit) .. trunc_symbol or filename
end

--- @param options table
--- @param buffer Buffer
--- @param diagnostic_count number
--- @return string
local function render_buffer(options, buffer, diagnostic_count)
  local buf_highlight, modified_hl_to_use = get_buffer_highlight(buffer)
  local length
  local is_current = buffer:current()

  local filename = truncate_filename(buffer.filename, options.max_name_length)
  local component = buffer.icon..padding..filename..padding

  if options.numbers ~= "none" then
    local number_prefix = get_number_prefix(
      buffer,
      options.numbers,
      options.number_style
    )
    local number_component = number_prefix .. padding
    component = number_component  .. component
  end

  -- string.len counts number of bytes and so the unicode icons are counted
  -- larger than their display width. So we use nvim's strwidth
  -- also avoid including highlight strings in the buffer length
  length = strwidth(component)
  component = make_clickable(options.mode, component, buffer.id)

  if is_current then
    -- U+2590 ▐ Right half block, this character is right aligned so the
    -- background highlight doesn't appear in th middle
    -- alternatives:  right aligned => ▕ ▐ ,  left aligned => ▍
    local indicator_symbol = '▎'
    local indicator = indicator_highlight .. indicator_symbol .. '%*'

    length = length + strwidth(indicator_symbol)
    component = indicator .. buf_highlight .. component
  else
    -- since all non-current buffers do not have an indicator they need
    -- to be padded to make up the difference in size
    length = length + strwidth(padding)
    component = buf_highlight .. padding .. component
  end

  if diagnostic_count > 0 then
    local diagnostic_section = diagnostic_count..padding
    component = component..diagnostic_highlight..diagnostic_section
    length = length + strwidth(diagnostic_section)
  end

  if buffer.modifiable and buffer.modified then
    local modified_icon = get_plugin_variable("modified_icon", "●")
    local modified_section = modified_icon..padding
    component = component..modified_hl_to_use..modified_section.."%X"
    length = length + strwidth(modified_section) -- icon(1) + padding(1)
  end

  if options.show_buffer_close_icons then
    local close_btn, size = close_button(buffer.id)
    component = component .. buf_highlight ..close_btn
    length = length + size
  end

  -- Use: https://en.wikipedia.org/wiki/Block_Elements
  -- separator is is "translucent" so coloring is more subtle
  -- a bit more like a real shadow
  -- TODO: investigate using a smaller block character (▍) at the start of the
  -- tab and end making sure to handle the empty space background highlight
  local separator_component = "░"
  local separator = separator_highlight..separator_component.."%X"
  length = length + strwidth(separator_component)
  return separator..component .."%X", length
end

local function tab_click_component(num)
  return "%"..num.."T"
end

local function render_tab(num, is_active)
  local hl = is_active and tab_selected_highlight or tab_highlight
  local name = padding.. num ..padding
  local length = strwidth(name)
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

local function render_close(icon)
  local component = padding .. icon .. padding
  return component, strwidth(component)
end

-- The provided api nvim_is_buf_loaded filters out all hidden buffers
local function is_valid(buffer)
  if not buffer or buffer < 1 then return false end
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

local function get_marker_size(count, element_size)
  return count > 0 and strwidth(count) + element_size or 0
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
  local left_trunc_marker = get_marker_size(marker.left_count, marker.left_element_size)
  local right_trunc_marker = get_marker_size(marker.right_count, marker.right_element_size)
  local markers_length = left_trunc_marker + right_trunc_marker
  local total_length = before.length + current.length + after.length + markers_length

  if available_width >= total_length then
    -- Merge all the buffers and render the components
    local buffers = array_concat(before.buffers, current.buffers, after.buffers)
    for _,buf in ipairs(buffers) do line = line .. buf.component end
    return line, marker
  else
    if before.length >= after.length then
      before:drop(1)
      marker.left_count = marker.left_count + 1
    else
      after:drop(#after.buffers)
      marker.right_count = marker.right_count + 1
    end
    return truncate(before, current, after, available_width, marker), marker
  end
end

local function render(buffers, tabs, close_length)
  local tab_components = ""
  local tabs_and_close_length = close_length

  -- Add the length of the tabs + close components to total length
  for _,t in pairs(tabs) do
    if not vim.tbl_isempty(t) then
      tabs_and_close_length = tabs_and_close_length + t.length
      tab_components = tab_components .. t.component
    end
  end

  -- Icons from https://fontawesome.com/cheatsheet
  local left_trunc_icon = get_plugin_variable("left_trunc_marker", "")
  local right_trunc_icon = get_plugin_variable("right_trunc_marker", "")
  -- measure the surrounding trunc items: padding + count + padding + icon + padding
  local left_element_size = strwidth(padding..padding..left_trunc_icon..padding)
  local right_element_size = strwidth(padding..padding..right_trunc_icon..padding)

  local available_width = api.nvim_get_option("columns") - tabs_and_close_length
  local before, current, after = get_sections(buffers)
  local line, marker = truncate(
    before,
    current,
    after,
    available_width,
    {
      left_count = 0,
      right_count = 0,
      left_element_size = left_element_size,
      right_element_size = right_element_size,
    }
  )

  -- TODO: Add a check to see if user wants fancy icons or not
  if marker.left_count > 0 then
    line = suffix_highlight .. padding..marker.left_count..padding..left_trunc_icon..padding ..line
  end
  if marker.right_count > 0 then
    line = line .. suffix_highlight .. padding..marker.right_count..padding..right_trunc_icon..padding
  end

  return tab_components..line
end

--- @param bufs table | nil
local function get_valid_buffers(bufs)
  local buf_nums = bufs or api.nvim_list_bufs()
  local valid_bufs = {}

  -- NOTE: In lua in order to iterate an array, indices should
  -- not contain gaps otherwise "ipairs" will stop at the first gap
  -- i.e the indices should be contiguous
  local count = 0
  for _,buf in ipairs(buf_nums) do
    if is_valid(buf) then
      count = count + 1
      valid_bufs[count] = buf
    end
  end
  return valid_bufs
end

--- @param array table
--- @return table
local function filter_duplicates(array)
  local seen = {}
  local res = {}

  for _,v in ipairs(array) do
    if (not seen[v]) then
      res[#res+1] = v
      seen[v] = true
    end
  end
  return res
end

--- @param mode string | nil
local function get_buffers_by_mode(mode)
--[[
  show only relevant buffers depending on the layout of the current tabpage:
    - In tabs with only one window all buffers are listed.
    - In tabs with more than one window, only the buffers that are being displayed are listed.
--]]
  if mode == "multiwindow" then
    local current_tab = api.nvim_get_current_tabpage()
    local is_single_tab = vim.fn.tabpagenr('$') == 1
    local number_of_tab_wins = vim.fn.tabpagewinnr(current_tab, '$')
    local valid_wins = 0
    -- Check that the window contains a listed buffer, if the buffre isn't
    -- listed we shouldn't be hiding the remaining buffers because of it
    -- FIXME this is sending an invalid buf_nr to is_valid buf
    for i=1,number_of_tab_wins do
      local buf_nr = vim.fn.winbufnr(i)
      if is_valid(buf_nr) then
        valid_wins = valid_wins + 1
      end
    end
    if valid_wins > 1 and not is_single_tab then
      -- TODO filter out duplicates because currently I don't know
      -- how to make it clear which buffer relates to which window
      -- buffers don't have an identifier to say which buffer they are in
      local unique = filter_duplicates(vim.fn.tabpagebuflist())
      return get_valid_buffers(unique), mode
    end
  end
  return get_valid_buffers(), nil
end

--[[
TODO
===========
 [ ] Investigate using guibg=none for modified symbol highlight instead of multiple
     highlight groups per status
 [ ] Buffer label truncation
 [ ] Highlight file type icons if possible see:
  https://github.com/weirongxu/coc-explorer/blob/59bd41f8fffdc871fbd77ac443548426bd31d2c3/src/icons.nerdfont.json#L2
--]]
--- @param options table<string, string>
--- @return string
local function bufferline(options)
  local buf_nums, current_mode = get_buffers_by_mode(options.view)
  local buffers = {}
  local tabs = get_tabs()
  options.view = current_mode

  for i, buf_id in ipairs(buf_nums) do
      local name =  api.nvim_buf_get_name(buf_id)
      local buf = Buffer:new {path = name, id = buf_id, ordinal = i}
      local component, length = render_buffer(options, buf, 0)
      buf.length = length
      buf.component = component
      buffers[i] = buf
  end

  local close_component, close_length = render_close(options.close_icon)
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
  local comment_fg = colors.get_hex('Comment', 'fg')
  local normal_fg = colors.get_hex('Normal', 'fg')
  local normal_bg = colors.get_hex('Normal', 'bg')
  local string_fg = colors.get_hex('String', 'fg')
  local tabline_sel_bg = colors.get_hex('TabLineSel', 'bg')

  -- If the colorscheme is bright we shouldn't do as much shading
  -- as this makes light color schemes harder to read
  local is_bright_background = colors.color_is_bright(normal_bg)
  local separator_shading = is_bright_background and -35 or -65
  local background_shading = is_bright_background and -15 or -30

  local separator_background_color = M.shade_color(normal_bg, separator_shading)
  local background_color = M.shade_color(normal_bg, background_shading)

  return {
    options = {
      view = "default",
      numbers = "none",
      number_style = "superscript",
      mappings = false,
      close_icon = "",
      max_name_length = 20,
      show_buffer_close_icons = true
    };
    highlights = {
      bufferline_tab = {
        guifg = comment_fg,
        guibg = normal_bg,
      };
      bufferline_tab_selected = {
        guifg = comment_fg,
        guibg = tabline_sel_bg,
      };
      bufferline_tab_close = {
        guifg = comment_fg,
        guibg = background_color
      };
      bufferline_buffer = {
        guifg = comment_fg,
        guibg = background_color,
      };
      bufferline_buffer_inactive = {
        guifg = comment_fg,
        guibg = normal_bg,
      };
      bufferline_modified = {
        guifg = string_fg,
        guibg = background_color,
      };
      bufferline_modified_inactive = {
        guifg = string_fg,
        guibg = normal_bg
      };
      bufferline_modified_selected = {
        guifg = string_fg,
        guibg = normal_bg
      };
      bufferline_separator = {
        guifg = separator_background_color,
        guibg = background_color,
      };
      bufferline_selected_indicator = {
        guifg = tabline_sel_bg,
        guibg = normal_bg,
      };
      bufferline_selected = {
        guifg = normal_fg,
        guibg = normal_bg,
        gui = "bold,italic",
      };
    }
  }
end

function M.go_to_buffer(num)
  local buf_nums = get_buffers_by_mode()
  if num <= table.getn(buf_nums) then
    vim.cmd("buffer "..buf_nums[num])
  end
end

-- TODO then validate user preferences and only set prefs that exists
function M.setup(prefs)
  local preferences = get_defaults()
  function _G.__setup_bufferline_colors()
    -- Combine user preferences with defaults preferring the user's own settings
    if prefs and type(prefs) == "table" then
      preferences = deep_merge(preferences, prefs)
    end

    local highlights = preferences.highlights

    colors.set_highlight('BufferLine', highlights.bufferline_buffer)
    colors.set_highlight('BufferLineInactive', highlights.bufferline_buffer_inactive)
    colors.set_highlight('BufferLineBackground', highlights.bufferline_buffer)
    colors.set_highlight('BufferLineSelected', highlights.bufferline_selected)
    colors.set_highlight('BufferLineSelectedIndicator', highlights.bufferline_selected_indicator)
    colors.set_highlight('BufferLineModified', highlights.bufferline_modified)
    colors.set_highlight('BufferLineModifiedSelected', highlights.bufferline_modified_selected)
    colors.set_highlight('BufferLineModifiedInactive', highlights.bufferline_modified_inactive)
    colors.set_highlight('BufferLineTab', highlights.bufferline_tab)
    colors.set_highlight('BufferLineSeparator', highlights.bufferline_separator)
    colors.set_highlight('BufferLineTabSelected', highlights.bufferline_tab_selected)
    colors.set_highlight('BufferLineTabClose', highlights.bufferline_tab_close)
  end

  nvim_create_augroups({
      BufferlineColors = {
        {"VimEnter", "*", [[lua __setup_bufferline_colors()]]};
        {"ColorScheme", "*", [[lua __setup_bufferline_colors()]]};
      }
    })

  -- The user's preferences are passed inside of a closure so they are accessible
  -- inside the globally defined lua function which is passed to the tabline setting
  function _G.__bufferline_render()
      return bufferline(preferences.options)
  end

  if preferences.options.mappings then
    for i=1, 10 do
      api.nvim_set_keymap('n', '<leader>'..i, ':lua require"bufferline".go_to_buffer('..i..')<CR>', {
          silent = true, nowait = true, noremap = true
        })
    end
  end

  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.__bufferline_render()"
end

return M
