local buffers = require("bufferline.buffers")
local constants = require("bufferline.constants")
local utils = require("bufferline.utils")

local Buffer = buffers.Buffer
local Buffers = buffers.Buffers

local api = vim.api
local fmt = string.format
-- string.len counts number of bytes and so the unicode icons are counted
-- larger than their display width. So we use nvim's strwidth
local strwidth = vim.fn.strwidth

local padding = constants.padding
local sep_names = constants.sep_names
local sep_chars = constants.sep_chars
local positions_key = constants.positions_key

local M = {}

-----------------------------------------------------------------------------//
-- State
-----------------------------------------------------------------------------//
local state = {
  is_picking = false,
  ---@type Buffer[]
  buffers = {},
  current_letters = {},
  custom_sort = nil,
}

if utils.is_test() then
  M._state = state
end

---------------------------------------------------------------------------//
-- CORE
---------------------------------------------------------------------------//
local function refresh()
  vim.cmd("redrawtabline")
  vim.cmd("redraw")
end

local function save_positions(bufs)
  local positions = table.concat(bufs, ",")
  vim.g[positions_key] = positions
end

function M.restore_positions()
  local str = vim.g[positions_key]
  if not str then
    return str
  end
  local buf_ids = vim.split(str, ",")
  if buf_ids and #buf_ids > 0 then
    -- these are converted to strings when stored
    -- so have to be converted back before usage
    state.custom_sort = vim.tbl_map(tonumber, buf_ids)
  end
end

function M.pick_buffer()
  state.is_picking = true
  refresh()

  local char = vim.fn.getchar()
  local letter = vim.fn.nr2char(char)
  for _, buf in pairs(state.buffers) do
    if letter == buf.letter then
      vim.cmd("buffer " .. buf.id)
    end
  end

  state.is_picking = false
  refresh()
end

---Handle a user "command" which can be a string or a function
---@param command string|function
---@param buf_id string
local function handle_user_command(command, buf_id)
  if not command then
    return
  end
  if type(command) == "function" then
    command(buf_id)
  elseif type(command) == "string" then
    vim.cmd(fmt(command, buf_id))
  end
end

---@param buf_id number
function M.handle_close_buffer(buf_id)
  local options = require("bufferline.config").get("options")
  local close = options.close_command
  handle_user_command(close, buf_id)
end

---@param id number
function M.handle_win_click(id)
  local win_id = vim.fn.bufwinid(id)
  vim.fn.win_gotoid(win_id)
end

---Handler for each type of mouse click
---@param id number
---@param button string
function M.handle_click(id, button)
  local options = require("bufferline.config").get("options")
  local cmds = {
    r = "right_mouse_command",
    l = "left_mouse_command",
    m = "middle_mouse_command",
  }
  if id then
    handle_user_command(options[cmds[button]], id)
  end
end

---@param buffer Buffer
---@param hls table<string, table<string, string>>
---@return table
local function get_buffer_highlight(buffer, hls)
  local hl = {}
  local h = hls

  if buffer:current() then
    hl.background = h.buffer_selected.hl
    hl.modified = h.modified_selected.hl
    hl.duplicate = h.duplicate_selected.hl
    hl.pick = h.pick_selected.hl
    hl.separator = h.separator_selected.hl
    hl.buffer = h.buffer_selected
    hl.diagnostic = h.diagnostic_selected.hl
    hl.error = h.error_selected.hl
    hl.error_diagnostic = h.error_diagnostic_selected.hl
    hl.warning = h.warning_selected.hl
    hl.warning_diagnostic = h.warning_diagnostic_selected.hl
    hl.info = h.info_selected.hl
    hl.info_diagnostic = h.info_diagnostic_selected.hl
    hl.close_button = h.close_button_selected.hl
  elseif buffer:visible() then
    hl.background = h.buffer_visible.hl
    hl.modified = h.modified_visible.hl
    hl.duplicate = h.duplicate_visible.hl
    hl.pick = h.pick_visible.hl
    hl.separator = h.separator_visible.hl
    hl.buffer = h.buffer_visible
    hl.diagnostic = h.diagnostic_visible.hl
    hl.error = h.error_visible.hl
    hl.error_diagnostic = h.error_diagnostic_visible.hl
    hl.warning = h.warning_visible.hl
    hl.warning_diagnostic = h.warning_diagnostic_visible.hl
    hl.info = h.info_visible.hl
    hl.info_diagnostic = h.info_diagnostic_visible.hl
    hl.close_button = h.close_button_visible.hl
  else
    hl.background = h.background.hl
    hl.modified = h.modified.hl
    hl.duplicate = h.duplicate.hl
    hl.pick = h.pick.hl
    hl.separator = h.separator.hl
    hl.buffer = h.background
    hl.diagnostic = h.diagnostic.hl
    hl.error = h.error.hl
    hl.error_diagnostic = h.error_diagnostic.hl
    hl.warning = h.warning.hl
    hl.warning_diagnostic = h.warning_diagnostic.hl
    hl.info = h.info.hl
    hl.info_diagnostic = h.info_diagnostic.hl
    hl.close_button = h.close_button.hl
  end

  return hl
end

--- @param mode string | nil
local function get_buffers_by_mode(mode)
  --[[
      show only relevant buffers depending on the layout of the current tabpage:
      - In tabs with only one window all buffers are listed.
      - In tabs with more than one window, only the buffers that are being displayed are listed.
  --]]
  if mode == "multiwindow" then
    local is_single_tab = vim.fn.tabpagenr("$") == 1
    if is_single_tab then
      return utils.get_valid_buffers()
    end

    local tab_wins = api.nvim_tabpage_list_wins(0)

    local valid_wins = 0
    for _, win_id in ipairs(tab_wins) do
      -- Check that the window contains a listed buffer, if the buffer isn't
      -- listed we shouldn't be hiding the remaining buffers because of it
      -- note this is to stop temporary unlisted buffers like fzf from
      -- triggering this mode
      local buf_nr = vim.api.nvim_win_get_buf(win_id)
      if utils.is_valid(buf_nr) then
        valid_wins = valid_wins + 1
      end
    end

    if valid_wins > 1 then
      local unique = utils.filter_duplicates(vim.fn.tabpagebuflist())
      return utils.get_valid_buffers(unique)
    end
  end
  return utils.get_valid_buffers()
end

local function truncate_filename(filename, word_limit)
  local trunc_symbol = "…"
  local too_long = string.len(filename) > word_limit
  if not too_long then
    return filename
  end
  -- truncate nicely by seeing if we can drop the extension first
  -- to make things fit if not then truncate abruptly
  local without_prefix = vim.fn.fnamemodify(filename, ":t:r")
  if string.len(without_prefix) < word_limit then
    return without_prefix .. trunc_symbol
  else
    return string.sub(filename, 0, word_limit - 1) .. trunc_symbol
  end
end

--- @param buffer Buffer
--- @return string
local function highlight_icon(buffer)
  local colors = require("bufferline.colors")
  local icon = buffer.icon
  local hl = buffer.icon_highlight

  if not icon or icon == "" then
    return ""
  elseif not hl or hl == "" then
    return icon
  end

  local prefix = "Bufferline"
  local new_hl = prefix .. hl
  local bg_hl = prefix .. "Background"
  -- TODO do not depend directly on style names
  if buffer:current() then
    new_hl = new_hl .. "Selected"
    bg_hl = prefix .. "BufferSelected"
  elseif buffer:visible() then
    new_hl = new_hl .. "Inactive"
    bg_hl = prefix .. "BufferVisible"
  end
  local guifg = colors.get_hex({ name = hl, attribute = "fg" })
  local guibg = colors.get_hex({ name = bg_hl, attribute = "bg" })
  require("bufferline.highlights").set_one(new_hl, { guibg = guibg, guifg = guifg })
  return "%#" .. new_hl .. "#" .. icon .. padding .. "%*"
end

---Determine if the separator style is one of the slant options
---@param style string
---@return boolean
local function is_slant(style)
  return vim.tbl_contains({ sep_names.slant, sep_names.padded_slant }, style)
end

--- "▍" "░"
--- Reference: https://en.wikipedia.org/wiki/Block_Elements
--- @param focused boolean
--- @param style table | string
local function get_separator(focused, style)
  if type(style) == "table" then
    return focused and style[1] or style[2]
  end
  local chars = sep_chars[style] or sep_chars.thin
  if is_slant(style) then
    return chars[1], chars[2]
  end
  return focused and chars[1] or chars[2]
end

--- @param buf_id number
local function close_icon(buf_id, context)
  local buffer_close_icon = context.preferences.options.buffer_close_icon
  local close_button_hl = context.current_highlights.close_button

  local symbol = buffer_close_icon .. padding
  local size = strwidth(symbol)
  return "%" .. buf_id .. "@nvim_bufferline#handle_close_buffer@" .. close_button_hl .. symbol, size
end

--- @param context table
local function modified_component(context)
  local modified_icon = context.preferences.options.modified_icon
  local modified_section = modified_icon .. padding
  return modified_section, strwidth(modified_section)
end

--- @param context table
local function indicator_component(context)
  local buffer = context.buffer
  local length = context.length
  local component = context.component
  local hl = context.preferences.highlights
  local curr_hl = context.current_highlights
  local options = context.preferences.options
  local style = options.separator_style

  if buffer:current() then
    local indicator = " "
    local symbol = indicator
    if not is_slant(style) then
      symbol = options.indicator_icon
      indicator = hl.indicator_selected.hl .. symbol .. "%*"
    end
    length = length + strwidth(symbol)
    component = indicator .. curr_hl.background .. component
  else
    -- since all non-current buffers do not have an indicator they need
    -- to be padded to make up the difference in size
    length = length + strwidth(padding)
    component = curr_hl.background .. padding .. component
  end
  return component, length
end

--- @param context table
local function add_prefix(context)
  local component = context.component
  local options = context.preferences.options
  local buffer = context.buffer
  local hl = context.current_highlights
  local length = context.length

  if state.is_picking and buffer.letter then
    component = hl.pick .. buffer.letter .. padding .. hl.background .. component
    length = length + strwidth(buffer.letter) + strwidth(padding)
  elseif options.show_buffer_icons and buffer.icon then
    local icon_highlight = highlight_icon(buffer)
    component = icon_highlight .. hl.background .. component
    length = length + strwidth(buffer.icon .. padding)
  end
  return component, length
end

--- @param context table
local function add_suffix(context)
  local component = context.component
  local buffer = context.buffer
  local hl = context.current_highlights
  local length = context.length
  local options = context.preferences.options
  local modified, modified_size = modified_component(context)

  if options.show_buffer_close_icons then
    local close, size = close_icon(buffer.id, context)
    local suffix = buffer.modified and hl.modified .. modified or close
    component = component .. hl.background .. suffix
    length = length + (buffer.modified and modified_size or size)
  end
  return component, length
end

--- TODO We increment the buffer length by the separator although the final
--- buffer will not have a separator so we are technically off by 1
--- @param context table
local function separator_components(context)
  local buffer = context.buffer
  local length = context.length
  local hl = context.preferences.highlights
  local style = context.preferences.options.separator_style
  local curr_hl = context.current_highlights
  local focused = buffer:current() or buffer:visible()

  local right_sep, left_sep = get_separator(focused, style)

  local sep_hl = hl.separator.hl
  if is_slant(style) then
    sep_hl = curr_hl.separator
  end

  local right_separator = sep_hl .. right_sep

  local left_separator = left_sep and (sep_hl .. left_sep) or nil
  length = length + strwidth(right_sep)

  if left_sep then
    length = length + strwidth(left_sep)
  end

  return length, left_separator, right_separator
end

local function enforce_regular_tabs(context)
  local _, modified_size = modified_component(context)
  local options = context.preferences.options
  local buffer = context.buffer
  local icon_size = strwidth(buffer.icon)
  local padding_size = strwidth(padding) * 2
  local max_length = options.max_name_length

  -- if we are enforcing regular tab size then all tabs will try and fit
  -- into the maximum tab size. If not we enforce a minimum tab size
  -- and allow tabs to be larger then the max otherwise
  if options.enforce_regular_tabs then
    -- estimate the maximum allowed size of a filename given that it will be
    -- padded and prefixed with a file icon
    max_length = options.tab_size - modified_size - icon_size - padding_size
  end
  return max_length
end

--- @param context table
local function pad_buffer(context)
  local component = context.component
  local options = context.preferences.options
  local length = context.length
  local buffer = context.buffer
  local hl = context.current_highlights
  local modified, size = modified_component(context)
  local modified_padding = string.rep(padding, size)

  if not options.show_buffer_close_icons then
    -- If the buffer is modified add an icon, if it isn't pad
    -- the buffer so it doesn't "jump" when it becomes modified i.e. due
    -- to the sudden addition of a new character
    local suffix = buffer.modified and hl.modified .. modified or modified_padding
    component = modified_padding .. context.component .. suffix
    length = context.length + (size * 2)
  end
  -- pad each tab smaller than the max tab size to make it consistent
  local difference = options.tab_size - length
  if difference > 0 then
    local pad = string.rep(padding, math.floor(difference / 2))
    component = pad .. component .. pad
    length = length + strwidth(pad) * 2
  end
  return component, length
end

--- @param preferences table
--- @param buffer Buffer
--- @return function,number
local function render_buffer(preferences, buffer)
  local hl = get_buffer_highlight(buffer, preferences.highlights)
  local ctx = {
    length = 0,
    component = "",
    preferences = preferences,
    current_highlights = hl,
    buffer = buffer,
  }

  -- Order matter here as this is the sequence which builds up the tab component
  local max_length = enforce_regular_tabs(ctx)
  local filename = truncate_filename(buffer.filename, max_length)
  -- escape filenames that contain "%" as this breaks in statusline patterns
  filename = filename:gsub("%%", "%%%1")

  ctx.component = filename
  ctx.length = ctx.length + strwidth(ctx.component)
  --- apply diagnostics first since we want the highlight
  --- to only apply to the filename
  ctx.component, ctx.length = require("bufferline.diagnostics").component(ctx)

  ctx.component = ctx.component .. padding
  ctx.length = ctx.length + strwidth(padding)

  ctx.component, ctx.length = require("bufferline.duplicates").component(ctx)
  ctx.component, ctx.length = add_prefix(ctx)
  ctx.component, ctx.length = pad_buffer(ctx)
  ctx.component, ctx.length = require("bufferline.numbers").component(ctx)
  ctx.component = utils.make_clickable(ctx)
  ctx.component, ctx.length = indicator_component(ctx)

  ctx.component, ctx.length = add_suffix(ctx)

  local length, left_sep, right_sep = separator_components(ctx)
  ctx.length = length

  -- NOTE: the component is wrapped in an item -> %(content) so
  -- vim counts each item as one rather than all of its individual
  -- sub-components.
  local buffer_component = "%(" .. ctx.component .. "%)"

  --- We return a function from render buffer as we do not yet have access to
  --- information regarding which buffers will actually be rendered
  --- @param index number
  --- @param num_of_bufs number
  --- @returns string
  local fn = function(index, num_of_bufs)
    if left_sep then
      buffer_component = left_sep .. buffer_component .. right_sep
    elseif index < num_of_bufs then
      buffer_component = buffer_component .. right_sep
    end
    return buffer_component
  end

  return fn, ctx.length
end

local function render_close(icon)
  local component = padding .. icon .. padding
  return component, strwidth(component)
end

local function get_sections(bufs)
  local current = Buffers:new()
  local before = Buffers:new()
  local after = Buffers:new()

  for _, buf in ipairs(bufs) do
    if buf:current() then
      -- We haven't reached the current buffer yet
      current:add(buf)
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

local function truncation_component(count, icon, hls)
  return utils.join(hls.fill.hl, padding, count, padding, icon, padding)
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
    -- if we aren't even able to fit the current buffer into the
    -- available space that means the window is really narrow
    -- so don't show anything
    -- Merge all the buffers and render the components
    local bufs = utils.array_concat(before.buffers, current.buffers, after.buffers)
    for index, buf in ipairs(bufs) do
      line = line .. buf.component(index, #bufs)
    end
    return line, marker
  elseif available_width < current.length then
    return "", marker
  else
    if before.length >= after.length then
      before:drop(1)
      marker.left_count = marker.left_count + 1
    else
      after:drop(#after.buffers)
      marker.right_count = marker.right_count + 1
    end
    -- drop the markers if the window is too narrow
    -- this assumes we have dropped both before and after
    -- sections since if the space available is this small
    -- we have likely removed these
    if (current.length + markers_length) > available_width then
      marker.left_count = 0
      marker.right_count = 0
    end
    return truncate(before, current, after, available_width, marker), marker
  end
end

--- @param bufs Buffer[]
--- @param tbs number[]
--- @param prefs table
local function render(bufs, tbs, prefs)
  local options = prefs.options
  local hl = prefs.highlights
  local right_align = "%="
  local tab_components = ""
  local close, close_length = "", 0
  if options.show_close_icon then
    close, close_length = render_close(options.close_icon)
  end
  local tabs_length = 0

  if options.show_tab_indicators then
    -- Add the length of the tabs + close components to total length
    if #tbs > 1 then
      for _, t in pairs(tbs) do
        if not vim.tbl_isempty(t) then
          tabs_length = tabs_length + t.length
          tab_components = tab_components .. t.component
        end
      end
    end
  end

  local join = utils.join

  -- Icons from https://fontawesome.com/cheatsheet
  local left_trunc_icon = options.left_trunc_marker
  local right_trunc_icon = options.right_trunc_marker
  -- measure the surrounding trunc items: padding + count + padding + icon + padding
  local left_element_size = strwidth(join(padding, padding, left_trunc_icon, padding, padding))
  local right_element_size = strwidth(join(padding, padding, right_trunc_icon, padding))

  local offset_size, left_offset, right_offset = require("bufferline.offset").get(prefs)
  local custom_area_size, left_area, right_area = require("bufferline.custom_area").get(prefs)

  local available_width = vim.o.columns
    - custom_area_size
    - offset_size
    - tabs_length
    - close_length

  local before, current, after = get_sections(bufs)
  local line, marker = truncate(before, current, after, available_width, {
    left_count = 0,
    right_count = 0,
    left_element_size = left_element_size,
    right_element_size = right_element_size,
  })

  if marker.left_count > 0 then
    local icon = truncation_component(marker.left_count, left_trunc_icon, hl)
    line = join(hl.background.hl, icon, padding, line)
  end
  if marker.right_count > 0 then
    local icon = truncation_component(marker.right_count, right_trunc_icon, hl)
    line = join(line, hl.background.hl, icon)
  end

  return join(
    left_offset,
    left_area,
    line,
    hl.fill.hl,
    right_align,
    tab_components,
    hl.tab_close.hl,
    close,
    right_area,
    right_offset
  )
end

--- TODO can this be done more efficiently in one loop?
--- @param buf_nums number[]
--- @param sorted number[]
--- @return number[]
local function get_updated_buffers(buf_nums, sorted)
  if not sorted then
    return buf_nums
  end
  local updated = {}
  -- add only buffers from our sort that are (still) in the
  -- canonical buffer list, maintaining the order
  for _, b in ipairs(sorted) do
    if vim.tbl_contains(buf_nums, b) then
      table.insert(updated, b)
    end
  end
  -- add any buffers from the buffer list that aren't in our sort
  for _, b in ipairs(buf_nums) do
    if not vim.tbl_contains(sorted, b) then
      table.insert(updated, b)
    end
  end
  return updated
end

---Filter the buffers to show based on the user callback passed in
---@param buf_nums integer[]
---@param callback fun(buf: integer, bufs: integer[]): boolean
---@return integer[]
local function apply_buffer_filter(buf_nums, callback)
  if type(callback) ~= "function" then
    return buf_nums
  end
  local filtered = {}
  for _, buf in ipairs(buf_nums) do
    if callback(buf, buf_nums) then
      table.insert(filtered, buf)
    end
  end
  return filtered
end

--- @param preferences table
--- @return string
local function bufferline(preferences)
  local options = preferences.options
  local buf_nums = get_buffers_by_mode(options.view)
  if options.custom_filter then
    buf_nums = apply_buffer_filter(buf_nums, options.custom_filter)
  end
  buf_nums = get_updated_buffers(buf_nums, state.custom_sort)
  local all_tabs = require("bufferline.tabs").get(options.separator_style, preferences)

  if not options.always_show_bufferline then
    if #buf_nums == 1 then
      vim.o.showtabline = 0
      return
    end
  end

  local letters = require("bufferline.letters")
  local duplicates = require("bufferline.duplicates")

  letters.reset()
  duplicates.reset()
  state.buffers = {}
  local all_diagnostics = require("bufferline.diagnostics").get(options)

  for i, buf_id in ipairs(buf_nums) do
    local name = vim.fn.bufname(buf_id)
    local buf = Buffer:new({
      path = name,
      id = buf_id,
      ordinal = i,
      diagnostics = all_diagnostics[buf_id],
    })
    duplicates.mark(state.buffers, buf, function(b)
      b.component, b.length = render_buffer(preferences, b)
    end)
    buf.letter = letters.get(buf)
    buf.component, buf.length = render_buffer(preferences, buf)
    state.buffers[i] = buf
  end

  -- if the user has reschuffled the buffers manually don't try and sort them
  if not state.custom_sort then
    require("bufferline.sorters").sort_buffers(preferences.options.sort_by, state.buffers)
  end

  return render(state.buffers, all_tabs, preferences)
end

---@param num number
function M.go_to_buffer(num)
  local buf_nums = get_buffers_by_mode()
  buf_nums = get_updated_buffers(buf_nums, state.custom_sort)
  if num <= #buf_nums then
    vim.cmd("buffer " .. buf_nums[num])
  end
end

local function get_current_buf_index()
  local current = api.nvim_get_current_buf()
  local index

  for i, buf in ipairs(state.buffers) do
    if buf.id == current then
      index = i
      break
    end
  end
  return index
end

--- @param bufs Buffer[]
--- @return number[]
local function get_buf_ids(bufs)
  return vim.tbl_map(function(buf)
    return buf.id
  end, bufs)
end

--- @param direction number
function M.move(direction)
  local index = get_current_buf_index()
  if not index then
    return utils.echoerr("Unable to find buffer to move, sorry")
  end
  local next_index = index + direction
  if next_index >= 1 and next_index <= #state.buffers then
    local cur_buf = state.buffers[index]
    local destination_buf = state.buffers[next_index]
    state.buffers[next_index] = cur_buf
    state.buffers[index] = destination_buf
    state.custom_sort = get_buf_ids(state.buffers)
    local opts = require("bufferline.config").get("options")
    if opts.persist_buffer_sort then
      save_positions(state.custom_sort)
    end
    refresh()
  end
end

function M.cycle(direction)
  local index = get_current_buf_index()
  if not index then
    return
  end
  local length = #state.buffers
  local next_index = index + direction

  if next_index <= length and next_index >= 1 then
    next_index = index + direction
  elseif index + direction <= 0 then
    next_index = length
  else
    next_index = 1
  end

  local next = state.buffers[next_index]

  if not next then
    return utils.echoerr("This buffer does not exist")
  end

  vim.cmd("buffer " .. next.id)
end

function M.toggle_bufferline()
  local listed_bufs = vim.fn.getbufinfo({ buflisted = 1 })
  if #listed_bufs > 1 then
    vim.o.showtabline = 2
  else
    vim.o.showtabline = 0
  end
end

--- sorts all buffers
--- @param sort_by string|function
function M.sort_buffers_by(sort_by)
  if next(state.buffers) == nil then
    return utils.echoerr("Unable to find buffers to sort, sorry")
  end

  require("bufferline.sorters").sort_buffers(sort_by, state.buffers)
  state.custom_sort = get_buf_ids(state.buffers)
  local opts = require("bufferline.config").get("options")
  if opts.persist_buffer_sort then
    save_positions(state.custom_sort)
  end
  refresh()
end

local function setup_autocommands(preferences)
  local autocommands = {
    { "ColorScheme", "*", [[lua __setup_bufferline_colors()]] },
  }
  if preferences.options.persist_buffer_sort then
    table.insert(autocommands, {
      "SessionLoadPost",
      "*",
      [[lua require'bufferline'.restore_positions()]],
    })
  end
  if not preferences.options.always_show_bufferline then
    -- toggle tabline
    table.insert(autocommands, {
      "VimEnter,BufAdd,TabEnter",
      "*",
      "lua require'bufferline'.toggle_bufferline()",
    })
  end
  local loaded = pcall(require, "nvim-web-devicons")
  if loaded then
    table.insert(autocommands, {
      "ColorScheme",
      "*",
      [[lua require'nvim-web-devicons'.setup()]],
    })
  end

  utils.nvim_create_augroups({ BufferlineColors = autocommands })
end

function M.setup(prefs)
  local config = require("bufferline.config")
  local preferences = config.set(prefs)

  -- on loading (and reloading) the plugin's config reset all the highlights
  require("bufferline.highlights").set_all(preferences.highlights)

  function _G.__setup_bufferline_colors()
    local current_prefs = config.update_highlights()
    require("bufferline.highlights").set_all(current_prefs.highlights)
  end

  setup_autocommands(preferences)
  -----------------------------------------------------------
  -- Commands
  -----------------------------------------------------------
  vim.cmd('command! BufferLinePick lua require"bufferline".pick_buffer()')
  vim.cmd('command! BufferLineCycleNext lua require"bufferline".cycle(1)')
  vim.cmd('command! BufferLineCyclePrev lua require"bufferline".cycle(-1)')
  vim.cmd('command! BufferLineMoveNext lua require"bufferline".move(1)')
  vim.cmd('command! BufferLineMovePrev lua require"bufferline".move(-1)')
  vim.cmd('command! BufferLineSortByExtension lua require"bufferline".sort_buffers_by("extension")')
  vim.cmd('command! BufferLineSortByDirectory lua require"bufferline".sort_buffers_by("directory")')
  vim.cmd(
    'command! BufferLineSortByRelativeDirectory lua require"bufferline".sort_buffers_by("relative_directory")'
  )

  -- TODO / idea: consider allowing these mappings to open buffers based on their
  -- visual position i.e. <leader>1 maps to the first visible buffer regardless
  -- of it actual ordinal number i.e. position in the full list or it's actual
  -- buffer id
  if preferences.options.mappings then
    for i = 1, 9 do
      api.nvim_set_keymap(
        "n",
        "<leader>" .. i,
        ':lua require"bufferline".go_to_buffer(' .. i .. ")<CR>",
        {
          silent = true,
          nowait = true,
          noremap = true,
        }
      )
    end
  end

  function _G.nvim_bufferline()
    return bufferline(config.get())
  end

  vim.o.showtabline = 2
  vim.o.tabline = "%!v:lua.nvim_bufferline()"
end

return M
