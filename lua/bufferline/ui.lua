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
---@type RenderContext
local Context = {}

---@param ctx RenderContext
---@return RenderContext
function Context:new(ctx)
  assert(ctx.tab, "A tab view entity is required to create a context")
  self.length = ctx.length or 0
  self.tab = ctx.tab
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

function M.refresh()
  vim.cmd("redrawtabline")
  vim.cmd("redraw")
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

local function modified_component()
  local modified_icon = config.options.modified_icon
  local modified_section = modified_icon .. padding
  return modified_section, strwidth(modified_section)
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
      line = line .. item.component(visible[index + 1])
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
  local length = context.length
  local element = context.tab
  local hl = context.current_highlights
  local options = config.options

  if not options.show_buffer_close_icons then
    -- If the buffer is modified add an icon, if it isn't pad
    -- the buffer so it doesn't "jump" when it becomes modified i.e. due
    -- to the sudden addition of a new character
    local modified, size = modified_component()
    local modified_padding = string.rep(padding, size)
    local suffix = element.modified and hl.modified .. modified or modified_padding
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

--- @param buffer Buffer
--- @param color_icons boolean whether or not to color the filetype icons
--- @param hl_defs BufferlineHighlights
--- @return string
local function highlight_icon(buffer, color_icons, hl_defs)
  local icon = buffer.icon
  local hl = buffer.icon_highlight

  if not icon or icon == "" then
    return ""
  end
  if not hl or hl == "" then
    return icon .. padding
  end

  local state = buffer:visibility()
  local bg_hls = {
    [visibility.INACTIVE] = hl_defs.buffer_visible.hl_name,
    [visibility.SELECTED] = hl_defs.buffer_selected.hl_name,
    [visibility.NONE] = hl_defs.background.hl_name,
  }

  local new_hl = highlights.generate_name(hl, { visibility = state })
  local guifg = not color_icons and "fg" or colors.get_hex({ name = hl, attribute = "fg" })
  local guibg = colors.get_hex({ name = bg_hls[state], attribute = "bg" })
  highlights.set_one(new_hl, { guibg = guibg, guifg = guifg })
  return highlights.hl(new_hl) .. icon .. padding .. "%*"
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
  local options = config.options
  local buffer_close_icon = options.buffer_close_icon
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
--- @return RenderContext
local function add_indicator(context)
  local element = context.tab
  local length = context.length
  local component = context.component
  local hl = config.highlights
  local options = config.options
  local curr_hl = context.current_highlights
  local style = options.separator_style

  if element:current() then
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
  local element = context.tab
  local hl = context.current_highlights
  local length = context.length
  local options = config.options

  if context.is_picking and element.letter then
    component, length = pick.component(context)
  elseif options.show_buffer_icons and element.icon then
    local icon_highlight = highlight_icon(element, options.color_icons, config.highlights)
    component = icon_highlight .. hl.background .. component
    length = length + strwidth(element.icon .. padding)
  end
  return context:update({ component = component, length = length })
end

--- @param context RenderContext
--- @return RenderContext
local function add_suffix(context)
  local component = context.component
  local element = context.tab
  local hl = context.current_highlights
  local options = config.options
  local length = context.length
  local modified, modified_size = modified_component()
  if not options.show_buffer_close_icons then
    return context
  end

  local close, size = close_icon(element.id, context)
  local suffix = element.modified and hl.modified .. modified or close
  component = component .. hl.background .. suffix
  length = length + (element.modified and modified_size or size)
  return context:update({ component = component, length = length })
end

--- TODO: We increment the buffer length by the separator although the final
--- buffer will not have a separator so we are technically off by 1
--- @param context RenderContext
--- @return RenderContext
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
---@return RenderContext
local function get_name(ctx)
  local max_length = get_max_length(ctx)
  local name = utils.truncate_name(ctx.tab.name, max_length)
  -- escape filenames that contain "%" as this breaks in statusline patterns
  name = name:gsub("%%", "%%%1")
  return ctx:update({ component = name, length = strwidth(name) })
end

--- @param context RenderContext
--- @return RenderContext
local function add_click_action(context)
  return context:update({
    component = require("bufferline.utils").make_clickable(
      "handle_click",
      context.tab.id,
      context.component
    ),
  })
end

---Create the render function that components need to position their
---separators once rendering calculations are complete
---@param ctx RenderContext
---@return fun(next: Component): string
local function create_renderer(ctx)
  --- We return a function from render buffer as we do not yet have access to
  --- information regarding which buffers will actually be rendered
  --- @param next_item Component
  --- @returns string
  return function(next_item)
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

    local sep = ctx.separators
    if sep.left then
      return sep.left .. buffer_component .. sep.right
    end

    if next_item then
      return buffer_component .. sep.right
    end

    return buffer_component
  end
end

--- @param state BufferlineState
--- @param buffer Buffer
--- @return Buffer
function M.element(state, buffer)
  local ctx = Context:new({
    tab = buffer,
    current_highlights = highlights.for_element(buffer),
    is_picking = state.is_picking,
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
    get_name,
    add_duplicates,
    add_group,
    add_padding({ right = 1 }),
    add_diagnostics,
    add_prefix,
    add_numbers,
    add_spacing,
    add_click_action,
    add_indicator,
    add_suffix,
    add_separators
  )(ctx)

  buffer.length, buffer.component = ctx.length, create_renderer(ctx)

  return buffer
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
    hl.fill.hl,
    right_align,
    tab_components,
    hl.tab_close.hl,
    close,
    right_area,
    right_offset
  ),
    visible_components
end

return M
