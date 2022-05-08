-----------------------------------------------------------------------------//
-- UI
-----------------------------------------------------------------------------//
local lazy = require("bufferline.lazy")
--- @module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
--- @module "bufferline.config"
local config = lazy.require("bufferline.config")
--- @module "bufferline.constants"
local constants = lazy.require("bufferline.constants")
--- @module "bufferline.highlights"
local highlights = lazy.require("bufferline.highlights")
--- @module "bufferline.colors"
local colors = require("bufferline.colors")
---@module "bufferline.pick"
local pick = lazy.require("bufferline.pick")
---@module "bufferline.groups"
local groups = lazy.require("bufferline.groups")

local M = {}
local visibility = constants.visibility
local sep_names = constants.sep_names
local sep_chars = constants.sep_chars
-- string.len counts number of bytes and so the unicode icons are counted
-- larger than their display width. So we use nvim's strwidth
local strwidth = vim.api.nvim_strwidth
local padding = constants.padding

-----------------------------------------------------------------------------//
-- Context
-----------------------------------------------------------------------------//

---@class RenderContext
---@field length number
---@field component string
---@field preferences BufferlineConfig
---@field current_highlights table<string, table<string, string>>
---@field tab Tabpage | Buffer
---@field separators table<string, string>
---@field is_picking boolean
---@field update fun(RenderContext, RenderContext):RenderContext
---@type RenderContext
local Context = {}

--- @class Segment
--- @field text string
--- @field highlight string
--- @field attr table<string, string | boolean>

---@param ctx RenderContext
---@return RenderContext
function Context:new(ctx)
  assert(ctx.tab, "A tab view entity is required to create a context")
  self.length = ctx.length or 0
  self.tab = ctx.tab
  self.component = ctx.component or {}
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

function M.refresh()
  vim.cmd("redrawtabline")
  vim.cmd("redraw")
end

---Add padding to either side of a component
---@param left number?
---@param right number?
---@return Segment, Segment
local function pad(left, right)
  left, right = left or 0, right or 0
  local left_p, right_p = string.rep(padding, left), string.rep(padding, right)
  return { text = left_p }, { text = right_p }
end

local function modified_component()
  return config.options.modified_icon .. padding
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
  return count > 0 and strwidth(tostring(count)) + element_size or 0
end

local function truncation_component(count, icon, hls)
  return utils.join(hls.fill.hl, padding, count, padding, icon, padding)
end

---@param component Segment[]
local function to_tabline_str(component)
  local str = ""
  for _, part in ipairs(component) do
    str = str
      .. highlights.hl(part.highlight)
      .. (part.attr and part.attr.prefix or "")
      .. (part.text or "")
      .. (part.attr and part.attr.suffix or "")
  end
  return str
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
      local component = item.component(visible[index + 1])
      line = line .. to_tabline_str(component)
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

--- @param length number
--- @return Segment?
local function add_space(length)
  local options = config.options
  -- pad each tab smaller than the max tab size to make it consistent
  local difference = options.tab_size - length
  if difference <= 0 then
    return
  end
  local size = math.floor(difference / 2)
  return pad(size, size)
end

--- @param buffer Buffer
--- @param color_icons boolean whether or not to color the filetype icons
--- @param hl_defs BufferlineHighlights
--- @return Segment?
local function get_icon_with_highlight(buffer, color_icons, hl_defs)
  local icon = buffer.icon
  local hl = buffer.icon_highlight

  if not icon or icon == "" then
    return
  end
  if not hl or hl == "" then
    return { text = icon .. padding }
  end

  local state = buffer:visibility()
  local bg_hls = {
    [visibility.INACTIVE] = hl_defs.buffer_visible.hl,
    [visibility.SELECTED] = hl_defs.buffer_selected.hl,
    [visibility.NONE] = hl_defs.background.hl,
  }

  local new_hl = highlights.generate_name(hl, { visibility = state })
  local hl_colors = {
    guifg = not color_icons and "fg" or colors.get_color({ name = hl, attribute = "fg" }),
    guibg = colors.get_color({ name = bg_hls[state], attribute = "bg" }),
    ctermfg = not color_icons and "fg" or colors.get_color({
      name = hl,
      attribute = "fg",
      cterm = true,
    }),
    ctermbg = colors.get_color({ name = bg_hls[state], attribute = "bg", cterm = true }),
  }
  highlights.set_one(new_hl, hl_colors)
  return { text = icon .. padding, highlight = new_hl, attr = { text = "%*" } }
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
local function get_close_icon(buf_id, context)
  local options = config.options
  local buffer_close_icon = options.buffer_close_icon
  local close_button_hl = context.current_highlights.close_button

  local symbol = buffer_close_icon .. padding
  local component = require("bufferline.utils").make_clickable(
    "handle_close_buffer",
    buf_id,
    -- the %X works as a closing label. @see :h tabline
    close_button_hl .. symbol .. "%X"
  )
  return { text = symbol, attrs = { click = component }, highlight = close_button_hl }
end

--- @param context RenderContext
--- @return Segment?
local function add_indicator(context)
  local element = context.tab
  -- local length = context.length
  -- local component = context.component
  local hl = config.highlights
  local options = config.options
  -- local curr_hl = context.current_highlights
  local style = options.separator_style

  if element:current() then
    local indicator = " "
    local symbol, highlight = indicator, nil
    if not is_slant(style) then
      symbol = options.indicator_icon
      indicator = symbol
      highlight = hl.indicator_selected.hl
    end
    -- length = length + strwidth(symbol)
    -- component = indicator .. curr_hl.background .. component
    return { text = indicator, highlight = highlight }
  end
  -- since all non-current buffers do not have an indicator they need
  -- to be padded to make up the difference in size
  -- length = length + strwidth(padding)
  -- component = curr_hl.background .. padding .. component
  return { text = padding }
end

--- @param context RenderContext
--- @return Segment?
local function add_icon(context)
  local element = context.tab
  local options = config.options
  if context.is_picking and element.letter then
    return pick.component(context)
  elseif options.show_buffer_icons and element.icon then
    return get_icon_with_highlight(element, options.color_icons, config.highlights)
  end
end

--- @param context RenderContext
--- @return Segment?
local function add_suffix(context)
  local element = context.tab
  local hl = context.current_highlights
  local symbol = modified_component()
  local modified = {
    text = element.modified and symbol or string.rep(padding, strwidth(symbol)),
    highlight = element.modified and hl.modified or nil,
  }
  -- local options = config.options
  -- if not options.show_buffer_close_icons then
  --   -- If the buffer is modified add an icon, if it isn't pad
  --   -- the buffer so it doesn't "jump" when it becomes modified i.e. due
  --   -- to the sudden addition of a new character
  --   modified = {
  --     text = element.modified and symbol or string.rep(padding, strwidth(symbol)),
  --     highlight = element.modified and hl.modified or nil,
  --   }
  -- end

  local close = get_close_icon(element.id, context)
  return not element.modified and close or modified
end

--- TODO: We increment the buffer length by the separator although the final
--- buffer will not have a separator so we are technically off by 1
--- @param context RenderContext
--- @return Segment?, Segment
local function add_separators(context)
  local element = context.tab
  local length = context.length
  local hl = config.highlights
  local options = config.options
  local style = options.separator_style
  local curr_hl = context.current_highlights
  local focused = element:current() or element:visible()

  local right_sep, left_sep = get_separator(focused, style)
  local sep_hl = is_slant(style) and curr_hl.separator or hl.separator.hl
  length = length + strwidth(right_sep)
  if left_sep then
    length = length + strwidth(left_sep)
  end

  local left_separator = left_sep and { text = left_sep, highlight = sep_hl } or nil
  local right_separator = { text = right_sep, highlight = sep_hl }
  return left_separator, right_separator
end

-- if we are enforcing regular tab size then all components will try and fit
-- into the maximum tab size. If not we enforce a minimum tab size
-- and allow components to be larger than the max.
---@param context RenderContext
---@return number
local function get_max_length(context)
  local _, modified_size = modified_component()
  local options = config.options
  local element = context.tab
  local icon_size = strwidth(element.icon)
  local padding_size = strwidth(padding) * 2
  local max_length = options.max_name_length

  if not options.enforce_regular_tabs then
    return max_length
  end
  -- estimate the maximum allowed size of a filename given that it will be
  -- padded and prefixed with a file icon
  return options.tab_size - modified_size - icon_size - padding_size
end

---@param ctx RenderContext
---@return Segment
local function get_name(ctx)
  local max_length = get_max_length(ctx)
  local name = utils.truncate_name(ctx.tab.name, max_length)
  -- escape filenames that contain "%" as this breaks in statusline patterns
  name = name:gsub("%%", "%%%1")
  return { text = name, highlight = ctx.current_highlights.buffer.hl }
end

--- @param context RenderContext
--- @return RenderContext
local function add_click_action(context)
  return context:update({
    component = require("bufferline.utils").make_clickable("handle_click", context.tab.id),
  })
end

---Create the render function that components need to position their
---separators once rendering calculations are complete
---@param left_separator Segment
---@param right_separator Segment
---@param component Segment[]
---@return fun(next: Component): Segment[]
local function create_renderer(left_separator, right_separator, component)
  --- We return a function from render buffer as we do not yet have access to
  --- information regarding which buffers will actually be rendered
  --- @param next_item Component
  --- @returns string
  return function(next_item)
    -- if using the non-slanted tab style then we must check if the component is at the end of
    -- of a section e.g. the end of a group and if so it should not be wrapped with separators
    -- as it can use those of the next item
    if not is_slant(config.options.separator_style) and next_item and next_item:is_end() then
      return component
    end

    if left_separator then
      table.insert(component, 1, left_separator)
      table.insert(component, right_separator)
      return component
    end

    if next_item then
      table.insert(component, right_separator)
    end

    return component
  end
end

---@param s Segment?
---@return boolean
local function is_not_empty(s)
  if s == nil or s.text == nil or s.text == "" then
    return false
  end
  return true
end

local function get_component_size(...)
  local sum = 0
  for _, s in ipairs({ ... }) do
    if is_not_empty(s) then
      sum = sum + strwidth(s.text)
    end
  end
  return sum
end

--- @param state BufferlineState
--- @param element TabElement
--- @return TabElement
function M.element(state, element)
  local ctx = Context:new({
    tab = element,
    current_highlights = highlights.for_element(element),
    is_picking = state.is_picking,
  })

  local add_diagnostics = require("bufferline.diagnostics").component
  local add_duplicates = require("bufferline.duplicates").component
  local add_numbers = require("bufferline.numbers").component
  --- Order matter here as this is the sequence which builds up the tab component
  --- each render function takes the context and returns an updated context with it's
  --- changes e.g. adding a modified icon to the context component or updating the
  --- length of the component
  -- ctx = utils.compose(
  --   get_name,
  --   add_duplicates,
  --   add_group,
  --   add_padding({ right = 1 }),
  --   add_diagnostics,
  --   add_icon,
  --   add_numbers,
  --   add_modified,
  --   add_space,
  --   add_click_action,
  --   add_indicator,
  --   add_suffix,
  --   add_separators
  -- )(ctx)

  local name = get_name(ctx)
  local duplicate_prefix = add_duplicates(ctx)
  local group_item = element.group and groups.component(ctx) or nil
  local diagnostic = add_diagnostics(ctx)
  local icon = add_icon(ctx)
  local number_prefix = add_numbers(ctx)
  local suffix = add_suffix(ctx)
  local text_size = get_component_size(
    name,
    duplicate_prefix,
    group_prefix,
    diagnostic,
    icon,
    number_prefix,
    suffix
  )
  local left_space, right_space = add_space(text_size)
  local indicator = add_indicator(ctx)
  local left, right = add_separators(ctx)

  local component = vim.tbl_filter(is_not_empty, {
    indicator,
    left_space,
    group_prefix,
    duplicate_prefix,
    number_prefix,
    icon,
    name,
    pad(1),
    diagnostic,
    suffix,
    right_space,
  })

  element.component = create_renderer(left, right, component)
  element.length = get_component_size(unpack(component))
  return element
end

--- @param components Component[]
--- @param tab_elements table[]
--- @return string
function M.render(components, tab_elements)
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
    if #tab_elements > 1 then
      for _, t in pairs(tab_elements) do
        if not vim.tbl_isempty(t) then
          tabs_length = tabs_length + t.length
          tab_components = tab_components .. t.component
        end
      end
    end
  end

  -- Icons from https://fontawesome.com/cheatsheet
  local left_trunc_icon = options.left_trunc_marker
  local right_trunc_icon = options.right_trunc_marker
  local left_element_size = utils.measure(padding, padding, left_trunc_icon, padding, padding)
  local right_element_size = utils.measure(padding, padding, right_trunc_icon, padding)

  local offset_size, left_offset, right_offset = require("bufferline.offset").get()
  local custom_area_size, left_area, right_area = require("bufferline.custom_area").get()

  local available_width = vim.o.columns
    - custom_area_size
    - offset_size
    - tabs_length
    - close_length

  local before, current, after = get_sections(components)
  local line, marker, visible_components = truncate(before, current, after, available_width, {
    left_count = 0,
    right_count = 0,
    left_element_size = left_element_size,
    right_element_size = right_element_size,
  })

  if marker.left_count > 0 then
    local icon = truncation_component(marker.left_count, left_trunc_icon, hl)
    line = utils.join(hl.background.hl, icon, padding, line)
  end
  if marker.right_count > 0 then
    local icon = truncation_component(marker.right_count, right_trunc_icon, hl)
    line = utils.join(line, hl.background.hl, icon)
  end

  return utils.join(
    left_offset,
    left_area,
    line,
    highlights.hl(hl.fill.hl),
    right_align,
    tab_components,
    highlights.hl(hl.tab_close.hl),
    close,
    right_area,
    right_offset
  ),
    visible_components
end

return M
