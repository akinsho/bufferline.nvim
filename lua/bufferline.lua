local constants = require("bufferline.constants")
local utils = require("bufferline.utils")

local api = vim.api
local fn = vim.fn
local fmt = string.format
-- string.len counts number of bytes and so the unicode icons are counted
-- larger than their display width. So we use nvim's strwidth
local strwidth = vim.fn.strwidth

local padding = constants.padding
local sep_names = constants.sep_names
local sep_chars = constants.sep_chars
local positions_key = constants.positions_key

local M = {}

--- Global namespace for callbacks and other use cases such as commandline completion functions
_G.__bufferline = __bufferline or {}

-----------------------------------------------------------------------------//
-- State
-----------------------------------------------------------------------------//
---@class BufferlineState
---@field components Component[]
---@field visible_components Component[]
---@field __components Component[]
---@field __visible_components Component[]
---@field custom_sort number[]
local state = {
  is_picking = false,
  custom_sort = nil,
  __components = {},
  __visible_components = {},
  components = {},
  visible_components = {},
}

-----------------------------------------------------------------------------//
-- Context
-----------------------------------------------------------------------------//

---@class RenderContext
---@field length number
---@field component string
---@field preferences BufferlineConfig
---@field current_highlights table<string, table<string, string>>
---@field tab Component
---@field separators table<string, string>
---@type RenderContext
local Context = {}

---@param ctx RenderContext
---@return RenderContext
function Context:new(ctx)
  assert(ctx.tab, "A tab view entity is required to create a context")
  assert(ctx.preferences, "The user's preferences are required to create a context")
  self.length = ctx.length or 0
  self.tab = ctx.tab
  self.preferences = ctx.preferences
  self.component = ctx.component or ""
  self.separators = ctx.component or { left = "", right = "" }
  self.__index = self
  return setmetatable(ctx, self)
end

---@param o RenderContext
---@return RenderContext
function Context:update(o)
  for k, v in pairs(o) do
    if v ~= nil then
      self[k] = v
    end
  end
  return self
end

-----------------------------------------------------------------------------//
-- Helpers
-----------------------------------------------------------------------------//

local function refresh()
  vim.cmd("redrawtabline")
  vim.cmd("redraw")
end

---@param bufs number[]
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

--- sorts buf_names in place, but doesn't add/remove any values
--- @param buf_nums number[]
--- @param sorted number[]
--- @return number[]
local function get_updated_buffers(buf_nums, sorted)
  if not sorted then
    return buf_nums
  end
  local nums = { unpack(buf_nums) }
  local reverse_lookup_sorted = utils.tbl_reverse_lookup(sorted)

  --- a comparator that sorts buffers by their position in sorted
  local sort_by_sorted = function(buf_id_1, buf_id_2)
    local buf_1_rank = reverse_lookup_sorted[buf_id_1]
    local buf_2_rank = reverse_lookup_sorted[buf_id_2]
    if not buf_1_rank then
      return false
    end
    if not buf_2_rank then
      return true
    end
    return buf_1_rank < buf_2_rank
  end
  table.sort(nums, sort_by_sorted)
  return nums
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

---------------------------------------------------------------------------//
-- User commands
---------------------------------------------------------------------------//

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

---@param group_id number
function M.handle_group_click(group_id)
  require("bufferline.groups").toggle_hidden(group_id)
  refresh()
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

---Execute an arbitrary user function on a visible by it's position buffer
---@param index number
---@param func fun(num: number)
function M.buf_exec(index, func)
  local target = state.visible_components[index]
  if target and type(func) == "function" then
    func(target, state.visible_components)
  end
end

-- Prompts user to select a buffer then applies a function to the buffer
---@param func fun(buf_id: number)
local function select_buffer_apply(func)
  state.is_picking = true
  refresh()

  local char = vim.fn.getchar()
  local letter = vim.fn.nr2char(char)
  for _, item in ipairs(state.components) do
    local buf = item:as_buffer()
    if buf and letter == buf.letter then
      func(buf.id)
    end
  end

  state.is_picking = false
  refresh()
end

function M.pick_buffer()
  select_buffer_apply(function(buf_id)
    vim.cmd("buffer " .. buf_id)
  end)
end

function M.close_buffer_with_pick()
  select_buffer_apply(function(buf_id)
    M.handle_close_buffer(buf_id)
  end)
end

--- Open a buffer based on it's visible position in the list
--- unless absolute is specified in which case this will open it based on it place in the full list
--- this is significantly less helpful if you have a lot of buffers open
---@param num number | string
---@param absolute boolean whether or not to use the buffers absolute position or visible positions
function M.go_to_buffer(num, absolute)
  num = type(num) == "string" and tonumber(num) or num
  local list = absolute and state.components or state.visible_components
  local buf = list[num]
  if buf then
    vim.cmd(fmt("buffer %d", buf.id))
  end
end

---@param opts table
---@return number
---@return Buffer
local function get_current_buf_index(opts)
  opts = opts or { include_hidden = false }
  local list = opts.include_hidden and state.__components or state.components
  local current = api.nvim_get_current_buf()
  for index, item in ipairs(list) do
    local buf = item:as_buffer()
    if buf and buf.id == current then
      return index, buf
    end
  end
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
  if next_index >= 1 and next_index <= #state.components then
    local cur_buf = state.components[index]
    local destination_buf = state.components[next_index]
    state.components[next_index] = cur_buf
    state.components[index] = destination_buf
    state.custom_sort = get_buf_ids(state.components)
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
  local length = #state.components
  local next_index = index + direction

  if next_index <= length and next_index >= 1 then
    next_index = index + direction
  elseif index + direction <= 0 then
    next_index = length
  else
    next_index = 1
  end

  local item = state.components[next_index]
  local next = item:as_buffer()

  if not next then
    return utils.echoerr("This buffer does not exist")
  end

  vim.cmd("buffer " .. next.id)
end

---@alias direction "'left'" | "'right'"
---Close all buffers to the left or right of the current buffer
---@param direction direction
function M.close_in_direction(direction)
  local index = get_current_buf_index()
  if not index then
    return
  end
  local length = #state.components
  if
    not (index == length and direction == "right") and not (index == 1 and direction == "left")
  then
    local start = direction == "left" and 1 or index + 1
    local _end = direction == "left" and index - 1 or length
    ---@type Buffer[]
    local bufs = vim.list_slice(state.components, start, _end)
    for _, buf in ipairs(bufs) do
      api.nvim_buf_delete(buf.id, { force = true })
    end
  end
end

--- sorts all buffers
--- @param sort_by string|function
function M.sort_buffers_by(sort_by)
  if next(state.components) == nil then
    return utils.echoerr("Unable to find buffers to sort, sorry")
  end

  require("bufferline.sorters").sort_buffers(sort_by, state.components)
  state.custom_sort = get_buf_ids(state.components)
  local opts = require("bufferline.config").get("options")
  if opts.persist_buffer_sort then
    save_positions(state.custom_sort)
  end
  refresh()
end

-----------------------------------------------------------------------------//
-- UI
-----------------------------------------------------------------------------//

--- TODO: find a tidier way to do this if possible
---@param buffer Buffer
---@param config BufferlineConfig
---@return table
local function get_buffer_highlight(buffer, config)
  local hl = {}
  local h = config.highlights

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
    hl.hint = h.hint_selected.hl
    hl.hint_diagnostic = h.hint_diagnostic_selected.hl
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
    hl.hint = h.hint_visible.hl
    hl.hint_diagnostic = h.hint_diagnostic_visible.hl
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
    hl.hint = h.hint.hl
    hl.hint_diagnostic = h.hint_diagnostic.hl
    hl.close_button = h.close_button.hl
  end

  if buffer.group then
    require("bufferline.groups").set_current_hl(buffer, h, hl)
  end

  return hl
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
    return icon .. padding
  end

  local prefix = "BufferLine"
  local new_hl = prefix .. hl
  local bg_hl = prefix .. "Background"
  -- TODO: do not depend directly on style names
  if buffer:current() then
    new_hl = new_hl .. "Selected"
    bg_hl = prefix .. "BufferSelected"
  elseif buffer:visible() then
    new_hl = new_hl .. "Inactive"
    bg_hl = prefix .. "BufferVisible"
  end
  local guifg = colors.get_hex({ name = hl, attribute = "fg" })
  local guibg = colors.get_hex({ name = bg_hl, attribute = "bg" })
  local H = require("bufferline.highlights")
  H.set_one(new_hl, { guibg = guibg, guifg = guifg })
  return H.hl(new_hl) .. icon .. padding .. "%*"
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
  local component = require("bufferline.utils").make_clickable(
    "handle_close_buffer",
    buf_id,
    -- the %X works as a closing label. @see :h tabline
    close_button_hl .. symbol .. "%X"
  )
  return component, size
end

--- @param context RenderContext
local function modified_component(context)
  local modified_icon = context.preferences.options.modified_icon
  local modified_section = modified_icon .. padding
  return modified_section, strwidth(modified_section)
end

--- @param context RenderContext
--- @return RenderContext
local function add_indicator(context)
  local buffer = context.tab:as_buffer()
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
  return context:update({ component = component, length = length })
end

--- @param context RenderContext
--- @return RenderContext
local function add_prefix(context)
  local component = context.component
  local options = context.preferences.options
  local buffer = context.tab:as_buffer()
  local hl = context.current_highlights
  local length = context.length

  if state.is_picking and buffer.letter then
    component, length = require("bufferline.pick").component(context)
  elseif options.show_buffer_icons and buffer.icon then
    local icon_highlight = highlight_icon(buffer)
    component = icon_highlight .. hl.background .. component
    length = length + strwidth(buffer.icon .. padding)
  end
  return context:update({ component = component, length = length })
end

--- @param context RenderContext
--- @return RenderContext
local function add_suffix(context)
  local component = context.component
  local buffer = context.tab:as_buffer()
  local hl = context.current_highlights
  local length = context.length
  local options = context.preferences.options
  local modified, modified_size = modified_component(context)
  if not options.show_buffer_close_icons then
    return context
  end

  local close, size = close_icon(buffer.id, context)
  local suffix = buffer.modified and hl.modified .. modified or close
  component = component .. hl.background .. suffix
  length = length + (buffer.modified and modified_size or size)
  return context:update({ component = component, length = length })
end

--- TODO: We increment the buffer length by the separator although the final
--- buffer will not have a separator so we are technically off by 1
--- @param context RenderContext
--- @return RenderContext
local function add_separators(context)
  local buffer = context.tab:as_buffer()
  local length = context.length
  local hl = context.preferences.highlights
  local style = context.preferences.options.separator_style
  local curr_hl = context.current_highlights
  local focused = buffer:current() or buffer:visible()

  local right_sep, left_sep = get_separator(focused, style)
  local sep_hl = is_slant(style) and curr_hl.separator or hl.separator.hl
  local right_separator = sep_hl .. right_sep
  local left_separator = left_sep and (sep_hl .. left_sep) or nil
  length = length + strwidth(right_sep)
  if left_sep then
    length = length + strwidth(left_sep)
  end

  return context:update({
    length = length,
    separators = {
      left = left_separator,
      right = right_separator,
    },
  })
end

-- if we are enforcing regular tab size then all components will try and fit
-- into the maximum tab size. If not we enforce a minimum tab size
-- and allow components to be larger than the max.
---@param context RenderContext
---@return number
local function enforce_regular_tabs(context)
  local _, modified_size = modified_component(context)
  local options = context.preferences.options
  local buffer = context.tab:as_buffer()
  local icon_size = strwidth(buffer.icon)
  local padding_size = strwidth(padding) * 2
  local max_length = options.max_name_length

  if not options.enforce_regular_tabs then
    return max_length
  end
  -- estimate the maximum allowed size of a filename given that it will be
  -- padded and prefixed with a file icon
  return options.tab_size - modified_size - icon_size - padding_size
end

--- @param context RenderContext
--- @return RenderContext
local function add_click_action(context)
  return context:update({
    component = require("bufferline.utils").make_clickable(
      "handle_click",
      context.tab:as_buffer().id,
      context.component
    ),
  })
end

---@class PadOpts
---@field left number?
---@field right number?
---@field component string
---@field length number

---Add padding to either side of a component
---@param opts PadOpts
---@return string, number
local function pad(opts)
  local left, right = opts.left or 0, opts.right or 0
  local left_p, right_p = string.rep(padding, left), string.rep(padding, right)
  local padded = left_p .. opts.component .. right_p
  return padded, strwidth(left_p) + strwidth(right_p) + opts.length
end

---@param sides table<'"right"' | '"left"',  number>
---@return fun(ctx: RenderContext): RenderContext
local function add_padding(sides)
  ---@param ctx RenderContext
  return function(ctx)
    local component, length = pad({
      left = sides.left,
      right = sides.right,
      component = ctx.component,
      length = ctx.length,
    })
    return ctx:update({ component = component, length = length })
  end
end

--- @param context RenderContext
--- @return RenderContext
local function add_spacing(context)
  local component = context.component
  local options = context.preferences.options
  local length = context.length
  local buffer = context.tab:as_buffer()
  local hl = context.current_highlights

  if not options.show_buffer_close_icons then
    -- If the buffer is modified add an icon, if it isn't pad
    -- the buffer so it doesn't "jump" when it becomes modified i.e. due
    -- to the sudden addition of a new character
    local modified, size = modified_component(context)
    local modified_padding = string.rep(padding, size)
    local suffix = buffer.modified and hl.modified .. modified or modified_padding
    component = modified_padding .. context.component .. suffix
    length = context.length + (size * 2)
  end
  -- pad each tab smaller than the max tab size to make it consistent
  local difference = options.tab_size - length
  if difference > 0 then
    local size = math.floor(difference / 2)
    component, length = pad({ left = size, right = size, component = component, length = length })
  end
  return context:update({ component = component, length = length })
end

---@param ctx RenderContext
---@return RenderContext
local function get_buffer_name(ctx)
  local max_length = enforce_regular_tabs(ctx)
  local filename = utils.truncate_filename(ctx.tab:as_buffer().filename, max_length)
  -- escape filenames that contain "%" as this breaks in statusline patterns
  filename = filename:gsub("%%", "%%%1")
  return ctx:update({ component = filename, length = strwidth(filename) })
end

--- @param config BufferlineConfig
--- @param buffer Buffer
--- @return BufferComponent,number
local function render_buffer(config, buffer)
  local ctx = Context:new({
    tab = buffer,
    preferences = config,
    current_highlights = get_buffer_highlight(buffer, config),
  })

  local add_diagnostics = require("bufferline.diagnostics").component
  local add_duplicates = require("bufferline.duplicates").component
  local add_numbers = require("bufferline.numbers").component
  local add_group = buffer.group and require("bufferline.groups").component or utils.identity

  --- Order matter here as this is the sequence which builds up the tab component
  --- each render function takes the context and returns an updated context with it's
  --- changes e.g. adding a modified icon to the context component or updating the
  --- length of the component
  ctx = utils.compose(
    get_buffer_name,
    add_group,
    add_padding({ right = 1 }),
    add_diagnostics,
    add_duplicates,
    add_prefix,
    add_numbers,
    add_spacing,
    add_click_action,
    add_indicator,
    add_suffix,
    add_separators
  )(ctx)

  --- We return a function from render buffer as we do not yet have access to
  --- information regarding which buffers will actually be rendered
  --- @param index number
  --- @param next_item Component
  --- @returns string
  local function render_fn(index, next_item)
    -- NOTE: the component is wrapped in an item -> %(content) so
    -- vim counts each item as one rather than all of its individual
    -- sub-components.
    local buffer_component = "%(" .. ctx.component .. "%)"

    -- if using the non-slanted tab style then we must check if the component is at the end of
    -- of a section e.g. the end of a group and if so it should not be wrapped with separators
    -- as it can use those of the next item
    if not is_slant(config.options.separator_style) and next_item and next_item:is_end() then
      return buffer_component
    end

    local s = ctx.separators
    if s.left then
      return s.left .. buffer_component .. s.right
    end

    if next_item then
      return buffer_component .. s.right
    end

    return buffer_component
  end

  return render_fn, ctx.length
end

---@param icon string
---@return string
---@return number
local function tab_close_button(icon)
  local component = padding .. icon .. padding
  return "%999X" .. component, strwidth(component)
end

---@param components Component[]
---@return Section
---@return Section
---@return Section
local function get_sections(components)
  local Section = require("bufferline.models").Section
  local current = Section:new()
  local before = Section:new()
  local after = Section:new()

  for _, tab_view in ipairs(components) do
    if not tab_view.hidden then
      if tab_view:current() then
        current:add(tab_view)
      elseif current.length == 0 then -- We haven't reached the current buffer yet
        before:add(tab_view)
      else
        after:add(tab_view)
      end
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

--- PREREQUISITE: active buffer always remains in view
--- 1. Find amount of available space in the window
--- 2. Find the amount of space the bufferline will take up
--- 3. If the bufferline will be too long remove one tab from the before or after
--- section
--- 4. Re-check the size, if still too long truncate recursively till it fits
--- 5. Add the number of truncated buffers as an indicator
---@param before Section
---@param current Section
---@param after Section
---@param available_width number
---@param marker table
---@return string
---@return table
---@return Buffer[]
local function truncate(before, current, after, available_width, marker, visible)
  visible = visible or {}
  local line = ""

  local left_trunc_marker = get_marker_size(marker.left_count, marker.left_element_size)
  local right_trunc_marker = get_marker_size(marker.right_count, marker.right_element_size)

  local markers_length = left_trunc_marker + right_trunc_marker

  local total_length = before.length + current.length + after.length + markers_length

  if available_width >= total_length then
    visible = utils.array_concat(before.items, current.items, after.items)
    for index, item in ipairs(visible) do
      line = line .. item.component(index, visible[index + 1])
    end
    return line, marker, visible
    -- if we aren't even able to fit the current buffer into the
    -- available space that means the window is really narrow
    -- so don't show anything
  elseif available_width < current.length then
    return "", marker, visible
  else
    if before.length >= after.length then
      before:drop(1)
      marker.left_count = marker.left_count + 1
    else
      after:drop(#after.items)
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
    return truncate(before, current, after, available_width, marker, visible)
  end
end

---@param list Component[]
---@return Component[]
local function filter_invisible(list)
  return utils.fold({}, function(accum, item)
    if item.focusable ~= false and not item.hidden then
      table.insert(accum, item)
    end
    return accum
  end, list)
end

---sort a list of components using a sort function
---@param list Component[]
---@return Component[]
local function sorter(list)
  -- if the user has reshuffled the buffers manually don't try and sort them
  if state.custom_sort then
    return list
  end
  local options = require("bufferline.config").get("options")
  require("bufferline.sorters").sort_buffers(options.sort_by, list)
  return list
end

--- @param components Component[]
--- @param tabpages table[]
--- @param config BufferlineConfig
--- @return string
local function render(components, tabpages, config)
  local options = config.options
  local hl = config.highlights
  local right_align = "%="
  local tab_components = ""
  local close, close_length = "", 0
  if options.show_close_icon then
    close, close_length = tab_close_button(options.close_icon)
  end
  local tabs_length = 0

  if options.show_tab_indicators then
    -- Add the length of the tabs + close components to total length
    if #tabpages > 1 then
      for _, t in pairs(tabpages) do
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
  local left_element_size = utils.measure(padding, padding, left_trunc_icon, padding, padding)
  local right_element_size = utils.measure(padding, padding, right_trunc_icon, padding)

  local offset_size, left_offset, right_offset = require("bufferline.offset").get(config)
  local custom_area_size, left_area, right_area = require("bufferline.custom_area").get(config)

  local available_width = vim.o.columns
    - custom_area_size
    - offset_size
    - tabs_length
    - close_length

  if config:enabled("groups") then
    components = require("bufferline.groups").render(components, sorter)
  else
    components = sorter(components)
  end

  local before, current, after = get_sections(components)
  local line, marker, visible_components = truncate(before, current, after, available_width, {
    left_count = 0,
    right_count = 0,
    left_element_size = left_element_size,
    right_element_size = right_element_size,
  })

  --- store the full unfiltered lists
  state.__components = components
  state.__visible_components = visible_components

  --- Store copies without focusable/hidden elements
  state.components = filter_invisible(components)
  state.visible_components = filter_invisible(visible_components)

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

--- @param config BufferlineConfig
--- @return string
local function bufferline(config)
  local options = config.options
  local buf_nums = utils.get_valid_buffers()
  if options and options.custom_filter then
    buf_nums = apply_buffer_filter(buf_nums, options.custom_filter)
  end
  buf_nums = get_updated_buffers(buf_nums, state.custom_sort)
  local tabpages = require("bufferline.tabpages").get(options.separator_style, config)

  if not options.always_show_bufferline then
    if #buf_nums == 1 then
      vim.o.showtabline = 0
      return
    end
  end

  local pick = require("bufferline.pick")
  local duplicates = require("bufferline.duplicates")
  local has_groups = config:enabled("groups")

  pick.reset()
  duplicates.reset()
  ---@type Buffer[]
  local buffers = {}
  local all_diagnostics = require("bufferline.diagnostics").get(options)
  local Buffer = require("bufferline.models").Buffer
  for i, buf_id in ipairs(buf_nums) do
    local buf = Buffer:new({
      path = vim.fn.bufname(buf_id),
      id = buf_id,
      ordinal = i,
      diagnostics = all_diagnostics[buf_id],
      name_formatter = options.name_formatter,
    })
    buf.letter = pick.get(buf)
    if has_groups then
      buf.group = require("bufferline.groups").set_id(buf)
    end
    buffers[i] = buf
  end

  local deduplicated = duplicates.mark(buffers)
  buffers = vim.tbl_map(function(buf)
    buf.component, buf.length = render_buffer(config, buf)
    return buf
  end, deduplicated)

  return render(buffers, tabpages, config)
end

function M.toggle_bufferline()
  local opts = require("bufferline.config").get("options")
  local status = (opts.always_show_bufferline or #fn.getbufinfo({ buflisted = 1 }) > 1) and 2 or 0
  vim.o.showtabline = status
end

---@private
function M.__apply_colors()
  local current_prefs = require("bufferline.config").update_highlights()
  require("bufferline.highlights").set_all(current_prefs.highlights)
end

---@param config BufferlineConfig
local function setup_autocommands(config)
  local options = config.options
  local autocommands = {
    { "ColorScheme", "*", [[lua require('bufferline').__apply_colors()]] },
  }
  if not options or vim.tbl_isempty(options) then
    return
  end
  if options.persist_buffer_sort then
    table.insert(autocommands, {
      "SessionLoadPost",
      "*",
      [[lua require'bufferline'.restore_positions()]],
    })
  end
  if not options.always_show_bufferline then
    -- toggle tabline
    table.insert(autocommands, {
      "BufAdd,TabEnter",
      "*",
      "lua require'bufferline'.toggle_bufferline()",
    })
  end

  if config:enabled("groups") then
    table.insert(autocommands, {
      "BufReadPre",
      "*",
      "++once",
      "lua vim.schedule(require'bufferline'.handle_group_enter)",
    })
    table.insert(autocommands, {
      "BufEnter",
      "*",
      "lua require'bufferline'.handle_group_enter()",
    })
  end

  utils.augroup({ BufferlineColors = autocommands })
end

---@alias group_actions '"close"' | '"toggle"'
---Execute an action on a group of buffers
---@param name string
---@param action group_actions | fun(b: Buffer)
function M.group_action(name, action)
  assert(name, "A name must be passed to execute a group action")
  local groups = require("bufferline.groups")
  if action == "close" then
    groups.command(name, function(b)
      api.nvim_buf_delete(b.id, { force = true })
    end)
  elseif action == "toggle" then
    require("bufferline.groups").toggle_hidden(nil, name)
    refresh()
  elseif type(action) == "function" then
    groups.command(name, action)
  end
end

function M.handle_group_enter()
  local options = require("bufferline.config").get("options")
  local _, buf = get_current_buf_index({ include_hidden = true })
  if not buf then
    return
  end
  local groups = require("bufferline.groups")
  local current_group = groups.get_by_id(buf.group)
  if options.groups.options.toggle_hidden_on_enter then
    if current_group.hidden then
      groups.set_hidden(current_group.id, false)
    end
  end
  utils.for_each(state.components, function(tab)
    local group = groups.get_by_id(tab.group)
    if group and group.auto_close and group.id ~= current_group.id then
      groups.set_hidden(group.id, true)
    end
  end)
end

---@param arg_lead string
---@param cmd_line string
---@param cursor_pos number
---@return string[]
function __bufferline.complete_groups(arg_lead, cmd_line, cursor_pos)
  return require("bufferline.groups").names()
end

local function setup_commands()
  local cmds = {
    { name = "BufferLinePick", cmd = "pick_buffer()" },
    { name = "BufferLinePickClose", cmd = "close_buffer_with_pick()" },
    { name = "BufferLineCycleNext", cmd = "cycle(1)" },
    { name = "BufferLineCyclePrev", cmd = "cycle(-1)" },
    { name = "BufferLineCloseRight", cmd = 'close_in_direction("right")' },
    { name = "BufferLineCloseLeft", cmd = 'close_in_direction("left")' },
    { name = "BufferLineMoveNext", cmd = "move(1)" },
    { name = "BufferLineMovePrev", cmd = "move(-1)" },
    { name = "BufferLineSortByExtension", cmd = 'sort_buffers_by("extension")' },
    { name = "BufferLineSortByDirectory", cmd = 'sort_buffers_by("directory")' },
    { name = "BufferLineSortByRelativeDirectory", cmd = 'sort_buffers_by("relative_directory")' },
    { name = "BufferLineSortByTabs", cmd = 'sort_buffers_by("tabs")' },
    { name = "BufferLineGoToBuffer", cmd = "go_to_buffer(<q-args>)", nargs = 1 },
    {
      nargs = 1,
      name = "BufferLineGroupClose",
      cmd = 'group_action(<q-args>, "close")',
      complete = "complete_groups",
    },
    {
      nargs = 1,
      name = "BufferLineGroupToggle",
      cmd = 'group_action(<q-args>, "toggle")',
      complete = "complete_groups",
    },
  }
  for _, cmd in ipairs(cmds) do
    local nargs = cmd.nargs and fmt("-nargs=%d", cmd.nargs) or ""
    local complete = cmd.complete
        and fmt("-complete=customlist,v:lua.__bufferline.%s", cmd.complete)
      or ""
    vim.cmd(
      fmt('command! %s %s %s lua require("bufferline").%s', nargs, complete, cmd.name, cmd.cmd)
    )
  end
end

---@private
function _G.nvim_bufferline()
  return bufferline(require("bufferline.config").get())
end

---@private
function M.__load()
  local config = require("bufferline.config")
  local preferences = config.apply()
  -- on loading (and reloading) the plugin's config reset all the highlights
  require("bufferline.highlights").set_all(preferences.highlights)
  -- TODO: don't reapply commands and autocommands if load has already been called
  setup_commands()
  setup_autocommands(preferences)
  vim.o.tabline = "%!v:lua.nvim_bufferline()"
  M.toggle_bufferline()
end

---@param config BufferlineConfig
function M.setup(config)
  config = config or {}
  require("bufferline.config").set(config)
  if vim.v.vim_did_enter == 1 then
    M.__load()
  else
    -- defer the first load of the plugin till vim has started
    require("bufferline.utils").augroup({
      BufferlineLoad = { { "VimEnter", "*", "++once", "lua require('bufferline').__load()" } },
    })
  end
end

if utils.is_test() then
  M._state = state
  M._get_current_buf_index = get_current_buf_index
end

return M
