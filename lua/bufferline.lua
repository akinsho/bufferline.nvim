require 'buffers'

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
local selected_indicator_highlight = '%#BufferLineSelectedIndicator#'
local modified_highlight = '%#BufferLineModified#'
local modified_inactive_highlight = '%#BufferLineModifiedInactive#'
local modified_selected_highlight = '%#BufferLineModifiedSelected#'
local diagnostic_highlight = '%#ErrorMsg#'
local background = '%#BufferLineBackground#'
local separator_highlight = '%#BufferLineSeparator#'
local close = '%#BufferLine#%999X'

---------------------------------------------------------------------------//
-- Constants
---------------------------------------------------------------------------//
local padding = " "

---------------------------------------------------------------------------//
-- EXPORT
---------------------------------------------------------------------------//

local M = {}

---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
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

local function safely_get_var(var)
  local success, result =  pcall(function() api.nvim_get_var(var) end)
  if not success then
    return nil
  else
    return result
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

local function to_rgb(color)
  local r = tonumber(string.sub(color, 2,3), 16)
  local g = tonumber(string.sub(color, 4,5), 16)
  local b = tonumber(string.sub(color, 6), 16)
  return r, g, b
end

-- SOURCE:
-- https://stackoverflow.com/questions/5560248/programmatically-lighten-or-darken-a-hex-color-or-rgb-and-blend-colors
local function shade_color(color, percent)
  local r, g, b = to_rgb(color)

  -- If any of the colors are missing return "NONE" i.e. no highlight
  if not r or not g or not b then return "NONE" end

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

--- Determine whether to use black or white text
-- Ref: https://stackoverflow.com/a/1855903/837964
-- https://stackoverflow.com/questions/596216/formula-to-determine-brightness-of-rgb-color
local function color_is_bright(hex)
  if not hex then
    return false
  end
  local r, g, b = to_rgb(hex)
  -- If any of the colors are missing return false
  if not r or not g or not b then return false end
  -- Counting the perceptive luminance - human eye favors green color
  local luminance = (0.299*r + 0.587*g + 0.114*b)/255
  if luminance > 0.5 then
    return true -- Bright colors, black font
  else
    return false -- Dark colors, white font
  end
end

local function get_hex(hl_name, part)
  local id = vim.fn.hlID(hl_name)
  return vim.fn.synIDattr(id, part)
end

local function set_highlight(name, hl)
  if hl and table_size(hl) > 0 then
    local cmd = "highlight! "..name
    if hl.gui and hl.gui ~= "" then
      cmd = cmd.." ".."gui="..hl.gui
    end
    if hl.guifg and hl.guifg ~= "" then
      cmd = cmd.." ".."guifg="..hl.guifg
    end
    if hl.guibg and hl.guibg ~= "" then
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
    if vim.fn.exists('v:lua') > 0 then
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
    return selected_highlight, modified_selected_highlight
  elseif buffer:visible() then
    return inactive_highlight, modified_inactive_highlight
  else
    return highlight, modified_highlight
  end
end

local function render_buffer(buffer, diagnostic_count)
  local buf_highlight, modified_hl_to_use = get_buffer_highlight(buffer)
  local length
  local is_current = buffer:current()

  local component = buffer.icon..padding..buffer.filename..padding
  -- pad the non active buffer before the highlighting is applied
  if not is_current then
    component = padding .. component
  end
  -- string.len counts number of bytes and so the unicode icons are counted
  -- larger than their display width. So we use nvim's strwidth
  -- also avoid including highlight strings in the buffer length
  length = strwidth(component)
  component = buf_highlight..make_clickable(component, buffer.id)

  if is_current then
    -- U+2590 ▐ Right half block, this character is right aligned so the
    -- background highlight doesn't appear in th middle
    -- alternatives:  right aligned => ▕ ▐ ,  left aligned => ▍
    local active_indicator = '▎'
    local active_highlight = selected_indicator_highlight.. active_indicator .. '%*'
    length = length + strwidth(active_indicator)
    component = active_highlight .. component
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

local function render_close()
  local close_icon = get_plugin_variable("close_icon", " close ")
  return close_icon, strwidth(close_icon)
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
    if number_of_tab_wins > 1 and not is_single_tab then
      return get_valid_buffers(vim.fn.tabpagebuflist())
    end
  end
  return get_valid_buffers()
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
--- @param mode string
--- @return string
function M.bufferline(mode)
  local buf_nums = get_buffers_by_mode(mode)
  local buffers = {}
  local tabs = get_tabs()
  for i, buf_id in ipairs(buf_nums) do
      local name =  api.nvim_buf_get_name(buf_id)
      local buf = Buffer:new {path = name, id = buf_id, ordinal = i}
      local component, length = render_buffer(buf, 0)
      buf.length = length
      buf.component = component
      buffers[i] = buf
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
  local string_fg = get_hex('String', 'fg')
  local tabline_sel_bg = get_hex('TabLineSel', 'bg')

  -- If the colorscheme is bright we shouldn't do as much shading
  -- as this makes light color schemes harder to read
  local is_bright_background = color_is_bright(normal_bg)
  local separator_shading = is_bright_background and -35 or -65
  local background_shading = is_bright_background and -15 or -30

  local separator_background_color = shade_color(normal_bg, separator_shading)
  local background_color = shade_color(normal_bg, background_shading)

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
end

--[[
  TODO then validate user preferences and only set prefs that exists
--]]
function M.setup(prefs)
  function _G.setup_bufferline_colors()
    local highlights
    if prefs and type(prefs) == "table" then
      -- "keep" behavior means that left > right in terms of priority
      highlights = vim.tbl_extend("keep", prefs, get_defaults())
    else
      highlights = get_defaults()
    end

    set_highlight('BufferLine', highlights.bufferline_buffer)
    set_highlight('BufferLineInactive', highlights.bufferline_buffer_inactive)
    set_highlight('BufferLineBackground', highlights.bufferline_buffer)
    set_highlight('BufferLineSelected', highlights.bufferline_selected)
    set_highlight('BufferLineSelectedIndicator', highlights.bufferline_selected_indicator)
    set_highlight('BufferLineModified', highlights.bufferline_modified)
    set_highlight('BufferLineModifiedSelected', highlights.bufferline_modified_selected)
    set_highlight('BufferLineModifiedInactive', highlights.bufferline_modified_inactive)
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


  vim.o.showtabline = 2
  -- One day there will be a better way to do this
  -- NOTE: the '%%' is an escape sequence for  a '%' in string.format
  vim.o.tabline = string.format("%%!luaeval(\"require'bufferline'.bufferline('%s')\")", prefs.mode)
end

return M
