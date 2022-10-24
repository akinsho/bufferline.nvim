local M = {}

local api = vim.api
local fmt = string.format
local lazy = require("bufferline.lazy")
--- @module "bufferline.groups"
local groups = lazy.require("bufferline.groups")
--- @module "bufferline.utils"
local utils = lazy.require("bufferline.utils")
--- @module "bufferline.highlights"
local highlights = lazy.require("bufferline.highlights")
--- @module "bufferline.colors"
local colors = lazy.require("bufferline.colors")
--- @module "bufferline.colors"
local constants = lazy.require("bufferline.constants")

---@class DebugOpts
---@field logging boolean

---@class GroupOptions
---@field toggle_hidden_on_enter boolean re-open hidden groups on bufenter

---@class GroupOpts
---@field options GroupOptions
---@field items Group[]

---@class BufferlineIndicator
---@field style "underline" | "icon" | "none"
---@field icon string?

---@alias BufferlineMode 'tabs' | 'buffers'

---@alias DiagnosticIndicator fun(count: number, level: number, errors: table<string, any>, ctx: table<string, any>): string

---@class HoverOptions
---@field reveal string[]
---@field delay integer
---@field enabled boolean

---@class BufferlineOptions
---@field public mode BufferlineMode
---@field public view string
---@field public debug DebugOpts
---@field public numbers string
---@field public buffer_close_icon string
---@field public modified_icon string
---@field public close_icon string
---@field public close_command string | function
---@field public custom_filter fun(buf: number, bufnums: number[]): boolean
---@field public left_mouse_command string | function
---@field public right_mouse_command string | function
---@field public middle_mouse_command (string | function)?
---@field public indicator BufferlineIndicator
---@field public left_trunc_marker string
---@field public right_trunc_marker string
---@field public separator_style string
---@field public name_formatter (fun(path: string):string)?
---@field public tab_size number
---@field public truncate_names boolean
---@field public max_name_length number
---@field public color_icons boolean
---@field public show_buffer_icons boolean
---@field public show_buffer_close_icons boolean
---@field public show_buffer_default_icon boolean
---@field public show_close_icon boolean
---@field public show_tab_indicators boolean
---@field public show_duplicate_prefix boolean
---@field public enforce_regular_tabs boolean
---@field public always_show_bufferline boolean
---@field public persist_buffer_sort boolean
---@field public max_prefix_length number
---@field public sort_by string
---@field public diagnostics boolean | 'nvim_lsp' | 'coc'
---@field public diagnostics_indicator DiagnosticIndicator
---@field public diagnostics_update_in_insert boolean
---@field public offsets table[]
---@field public groups GroupOpts
---@field public themable boolean
---@field public hover HoverOptions

---@class BufferlineHLGroup
---@field fg string
---@field bg string
---@field sp string
---@field special string
---@field bold boolean
---@field italic boolean
---@field underline boolean
---@field undercurl boolean
---@field hl_group string
---@field hl_name string

---@alias BufferlineHighlights table<string, BufferlineHLGroup>

---@class BufferlineConfig
---@field public options BufferlineOptions
---@field public highlights BufferlineHighlights
---@field private user BufferlineConfig original copy of user preferences
---@field private merge fun(self: BufferlineConfig, defaults: BufferlineConfig): BufferlineConfig
---@field private validate fun(self: BufferlineConfig, defaults: BufferlineConfig, resolved: BufferlineHighlights): nil
---@field private resolve fun(self: BufferlineConfig, defaults: BufferlineConfig)
---@field private is_tabline fun():boolean

--- Convert highlights specified as tables to the correct existing colours
---@param map BufferlineHighlights
local function hl_table_to_color(map)
  if not map or vim.tbl_isempty(map) then return {} end
  -- we deep copy the highlights table as assigning the attributes
  -- will only pass the references so will mutate the original table otherwise
  local updated = vim.deepcopy(map)
  for hl, attributes in pairs(map) do
    for attribute, value in pairs(attributes) do
      if type(value) == "table" then
        if value.highlight and value.attribute then
          updated[hl][attribute] = colors.get_color({
            name = value.highlight,
            attribute = value.attribute,
            cterm = attribute:match("cterm") ~= nil,
          })
        else
          updated[hl][attribute] = nil
          utils.notify(fmt("removing %s as it is not formatted correctly", hl), "warn")
        end
      end
    end
  end
  return updated
end

---The local class instance of the merged user's configuration
---this includes all default values and highlights filled out
---@type BufferlineConfig
local config = {}

---The class definition for the user configuration
---@type BufferlineConfig
local Config = {}

function Config:new(o)
  assert(o, "User options must be passed in")
  self.__index = self
  -- save a copy of the user's preferences so we can reference exactly what they
  -- wanted after the config and defaults have been merged. Do this using a copy
  -- so that reference isn't unintentionally mutated
  self.user = vim.deepcopy(o)
  setmetatable(o, self)
  return o
end

---Combine user preferences with defaults preferring the user's own settings
---@param defaults BufferlineConfig
---@return BufferlineConfig
function Config:merge(defaults)
  assert(defaults and type(defaults) == "table", "A valid config table must be passed to merge")
  self.options = vim.tbl_deep_extend("force", defaults.options, self.options or {})
  self.highlights = vim.tbl_deep_extend("force", defaults.highlights, self.highlights or {})
  return self
end

local deprecations = {
  indicator_icon = {
    message = "It should be changed to indicator and icon specified as indicator.icon, with indicator.style = 'icon'",
    pending = true,
  },
}

---@param options BufferlineOptions
local function validate_user_options(options)
  if not options then return end
  for key, _ in pairs(options) do
    local deprecation = deprecations[key]
    if deprecation then
      vim.schedule(function()
        local timeframe = deprecation.pending and "will be" or "has been"
        utils.notify(fmt("'%s' %s deprecated: %s", key, timeframe, deprecation.message), "warn")
      end)
    end
  end
end

---@param options BufferlineOptions
---@return table[]
local function get_offset_highlights(options)
  if not options or not options.offsets then return {} end
  return utils.fold(function(accum, offset, i)
    if offset.highlight and type(offset.highlight) == "table" then
      accum[fmt("offset_%d", i)] = offset.highlight
    end
    return accum
  end, options.offsets)
end

---@param options BufferlineOptions
---@return table[]
local function get_group_highlights(options)
  if not options or not options.groups then return {} end
  return utils.fold(function(accum, group)
    if group.highlight then accum[group.name] = group.highlight end
    return accum
  end, options.groups.items)
end

local function validate_user_highlights(opts, defaults, hls)
  if not hls then return end
  local incorrect = { invalid_hl = {}, invalid_attrs = {} }

  local offset_highlights = get_offset_highlights(opts)
  local group_highlights = get_group_highlights(opts)
  local all_hls = vim.tbl_extend("force", {}, hls, offset_highlights, group_highlights)

  for k, hl in pairs(all_hls) do
    for key, _ in pairs(hl) do
      if key:match("gui") then table.insert(incorrect.invalid_attrs, fmt("- %s", k)) end
    end
    if hls[k] then
      if not defaults.highlights[k] then table.insert(incorrect.invalid_hl, k) end
    end
  end

  -- Don't continue if there are no incorrect highlights
  if next(incorrect.invalid_hl) then
    local is_plural = #incorrect > 1
    local msg = table.concat({
      table.concat(incorrect.invalid_hl, ", "),
      is_plural and " are " or " is ",
      "not",
      is_plural and " " or " a ",
      "valid highlight",
      is_plural and " groups. " or " group. ",
      "Please check :help bufferline-highlights for all valid highlights",
    })
    utils.notify(msg, "error")
  end
  if next(incorrect.invalid_attrs) then
    local msg = table.concat({
      "Using `gui`, `guifg`, `guibg`, `guisp` is deprecated please, convert these as follows: ",
      "- guifg -> fg",
      "- guibg -> bg",
      "- guisp -> sp",
      "- gui -> underline = true, undercurl = true, italic = true",
      " see :help bufferline-highlights for more details on how to update your highlights",
      "",
      "Please fix: ",
      unpack(incorrect.invalid_attrs),
    }, "\n")
    utils.notify(msg, "error")
  end
end

--- Check that the user has not placed setting in the wrong tables
---@param conf BufferlineConfig
local function validate_config_structure(conf)
  local invalid = {}
  for key, _ in pairs(conf) do
    if key ~= "options" and key ~= "highlights" then table.insert(invalid, " - " .. key) end
  end
  if next(invalid) then
    utils.notify({
      "All configuration should be inside of the options or highlights table",
      "the following keys are in the wrong place",
      unpack(invalid),
    }, "warn")
  end
end

---Ensure the user has only specified highlight groups that exist
---@param defaults BufferlineConfig
---@param resolved BufferlineHighlights
function Config:validate(defaults, resolved)
  validate_config_structure(self.user)
  validate_user_options(self.user.options)
  validate_user_highlights(self.user.options, defaults, resolved)
end

function Config:mode()
  if not self.options then return "buffers" end
  return self.options.mode
end

function Config:is_bufferline() return self:mode() == "buffers" end

function Config:is_tabline() return self:mode() == "tabs" end

---Derive the colors for the bufferline
---@return BufferlineHighlights
local function derive_colors()
  local hex = colors.get_color
  local shade = colors.shade_color

  local comment_fg = hex({
    name = "Comment",
    attribute = "fg",
    fallback = { name = "Normal", attribute = "fg" },
  })

  local normal_fg = hex({ name = "Normal", attribute = "fg" })
  local normal_bg = hex({ name = "Normal", attribute = "bg" })
  local string_fg = hex({ name = "String", attribute = "fg" })

  local error_hl = "DiagnosticError"
  local warning_hl = "DiagnosticWarn"
  local info_hl = "DiagnosticInfo"
  local hint_hl = "DiagnosticHint"

  local error_fg = hex({
    name = error_hl,
    attribute = "fg",
    fallback = { name = "Error", attribute = "fg" },
  })

  local warning_fg = hex({
    name = warning_hl,
    attribute = "fg",
    fallback = { name = "WarningMsg", attribute = "fg" },
  })

  local info_fg = hex({
    name = info_hl,
    attribute = "fg",
    fallback = { name = "Normal", attribute = "fg" },
  })

  local hint_fg = hex({
    name = hint_hl,
    attribute = "fg",
    fallback = { name = "Directory", attribute = "fg" },
  })

  local tabline_sel_bg = hex({
    name = "TabLineSel",
    attribute = "bg",
    not_match = normal_bg,
    fallback = {
      name = "TabLineSel",
      attribute = "fg",
      not_match = normal_bg,
      fallback = { name = "WildMenu", attribute = "fg" },
    },
  })

  local win_separator_fg = hex({
    name = "WinSeparator",
    attribute = "fg",
    fallback = {
      name = "VertSplit",
      attribute = "fg",
    },
  })

  -- If the colorscheme is bright we shouldn't do as much shading
  -- as this makes light color schemes harder to read
  local is_bright_background = colors.color_is_bright(normal_bg)
  local separator_shading = is_bright_background and -20 or -45
  local background_shading = is_bright_background and -12 or -25
  local diagnostic_shading = is_bright_background and -12 or -25

  local visible_bg = shade(normal_bg, -8)
  local duplicate_color = shade(comment_fg, -5)
  local separator_background_color = shade(normal_bg, separator_shading)
  local background_color = shade(normal_bg, background_shading)

  -- diagnostic colors by default are a few shades darker
  local normal_diagnostic_fg = shade(normal_fg, diagnostic_shading)
  local comment_diagnostic_fg = shade(comment_fg, diagnostic_shading)
  local hint_diagnostic_fg = shade(hint_fg, diagnostic_shading)
  local info_diagnostic_fg = shade(info_fg, diagnostic_shading)
  local warning_diagnostic_fg = shade(warning_fg, diagnostic_shading)
  local error_diagnostic_fg = shade(error_fg, diagnostic_shading)

  local indicator_style = vim.tbl_get(config, "user", "options", "indicator", "style")
  local has_underline_indicator = indicator_style == "underline"

  local underline_sp = has_underline_indicator and tabline_sel_bg or nil

  return {
    fill = {
      fg = comment_fg,
      bg = separator_background_color,
    },
    group_separator = {
      fg = comment_fg,
      bg = separator_background_color,
    },
    group_label = {
      bg = comment_fg,
      fg = separator_background_color,
    },
    tab = {
      fg = comment_fg,
      bg = background_color,
    },
    tab_selected = {
      fg = tabline_sel_bg,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    tab_close = {
      fg = comment_fg,
      bg = background_color,
    },
    close_button = {
      fg = comment_fg,
      bg = background_color,
    },
    close_button_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    close_button_selected = {
      fg = normal_fg,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    background = {
      fg = comment_fg,
      bg = background_color,
    },
    buffer = {
      fg = comment_fg,
      bg = background_color,
    },
    buffer_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    buffer_selected = {
      fg = normal_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    numbers = {
      fg = comment_fg,
      bg = background_color,
    },
    numbers_selected = {
      fg = normal_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    numbers_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    diagnostic = {
      fg = comment_diagnostic_fg,
      bg = background_color,
    },
    diagnostic_visible = {
      fg = comment_diagnostic_fg,
      bg = visible_bg,
    },
    diagnostic_selected = {
      fg = normal_diagnostic_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    hint = {
      fg = comment_fg,
      sp = hint_fg,
      bg = background_color,
    },
    hint_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    hint_selected = {
      fg = hint_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or hint_fg,
    },
    hint_diagnostic = {
      fg = comment_diagnostic_fg,
      sp = hint_diagnostic_fg,
      bg = background_color,
    },
    hint_diagnostic_visible = {
      fg = comment_diagnostic_fg,
      bg = visible_bg,
    },
    hint_diagnostic_selected = {
      fg = hint_diagnostic_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or hint_diagnostic_fg,
    },
    info = {
      fg = comment_fg,
      sp = info_fg,
      bg = background_color,
    },
    info_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    info_selected = {
      fg = info_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or info_fg,
    },
    info_diagnostic = {
      fg = comment_diagnostic_fg,
      sp = info_diagnostic_fg,
      bg = background_color,
    },
    info_diagnostic_visible = {
      fg = comment_diagnostic_fg,
      bg = visible_bg,
    },
    info_diagnostic_selected = {
      fg = info_diagnostic_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or info_diagnostic_fg,
    },
    warning = {
      fg = comment_fg,
      sp = warning_fg,
      bg = background_color,
    },
    warning_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    warning_selected = {
      fg = warning_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or warning_fg,
    },
    warning_diagnostic = {
      fg = comment_diagnostic_fg,
      sp = warning_diagnostic_fg,
      bg = background_color,
    },
    warning_diagnostic_visible = {
      fg = comment_diagnostic_fg,
      bg = visible_bg,
    },
    warning_diagnostic_selected = {
      fg = warning_diagnostic_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or warning_diagnostic_fg,
    },
    error = {
      fg = comment_fg,
      bg = background_color,
      sp = error_fg,
    },
    error_visible = {
      fg = comment_fg,
      bg = visible_bg,
    },
    error_selected = {
      fg = error_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or error_fg,
    },
    error_diagnostic = {
      fg = comment_diagnostic_fg,
      bg = background_color,
      sp = error_diagnostic_fg,
    },
    error_diagnostic_visible = {
      fg = comment_diagnostic_fg,
      bg = visible_bg,
    },
    error_diagnostic_selected = {
      fg = error_diagnostic_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      underline = has_underline_indicator,
      sp = underline_sp or error_diagnostic_fg,
    },
    modified = {
      fg = string_fg,
      bg = background_color,
    },
    modified_visible = {
      fg = string_fg,
      bg = visible_bg,
    },
    modified_selected = {
      fg = string_fg,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    duplicate_selected = {
      fg = duplicate_color,
      italic = true,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    duplicate_visible = {
      fg = duplicate_color,
      italic = true,
      bg = visible_bg,
    },
    duplicate = {
      fg = duplicate_color,
      italic = true,
      bg = background_color,
    },
    separator_selected = {
      fg = separator_background_color,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    separator_visible = {
      fg = separator_background_color,
      bg = visible_bg,
    },
    separator = {
      fg = separator_background_color,
      bg = background_color,
    },
    tab_separator = {
      fg = separator_background_color,
      bg = background_color,
    },
    tab_separator_selected = {
      fg = separator_background_color,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    indicator_selected = {
      fg = tabline_sel_bg,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    indicator_visible = {
      fg = visible_bg,
      bg = visible_bg,
    },
    pick_selected = {
      fg = error_fg,
      bg = normal_bg,
      bold = true,
      italic = true,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    pick_visible = {
      fg = error_fg,
      bg = visible_bg,
      bold = true,
      italic = true,
    },
    pick = {
      fg = error_fg,
      bg = background_color,
      bold = true,
      italic = true,
    },
    offset_separator = {
      fg = win_separator_fg,
      bg = separator_background_color,
    },
  }
end

-- Ideally this plugin should generate a beautiful tabline a little similar
-- to what you would get on other editors. The aim is that the default should
-- be so nice it's what anyone using this plugin sticks with. It should ideally
-- work across any well designed colorscheme deriving colors automagically.
-- Icons from https://fontawesome.com/cheatsheet
---@return BufferlineConfig
local function get_defaults()
  ---@type BufferlineOptions
  local opts = {
    mode = "buffers",
    themable = true, -- whether or not bufferline highlights can be overridden externally
    numbers = "none",
    buffer_close_icon = "",
    modified_icon = "●",
    close_icon = "",
    close_command = "bdelete! %d",
    left_mouse_command = "buffer %d",
    right_mouse_command = "bdelete! %d",
    middle_mouse_command = nil,
    -- U+2590 ▐ Right half block, this character is right aligned so the
    -- background highlight doesn't appear in the middle
    -- alternatives:  right aligned => ▕ ▐ ,  left aligned => ▍
    indicator = {
      icon = constants.indicator,
      style = "icon",
    },
    left_trunc_marker = "",
    right_trunc_marker = "",
    separator_style = "thin",
    name_formatter = nil,
    truncate_names = true,
    tab_size = 18,
    max_name_length = 18,
    color_icons = true,
    show_buffer_icons = true,
    show_buffer_close_icons = true,
    show_buffer_default_icon = true,
    show_close_icon = true,
    show_tab_indicators = true,
    show_duplicate_prefix = true,
    enforce_regular_tabs = false,
    always_show_bufferline = true,
    persist_buffer_sort = true,
    max_prefix_length = 15,
    sort_by = "id",
    diagnostics = false,
    diagnostics_indicator = nil,
    diagnostics_update_in_insert = true,
    offsets = {},
    groups = {
      items = {},
      options = {
        toggle_hidden_on_enter = true,
      },
    },
    hover = {
      enabled = false,
      reveal = {},
      delay = 200,
    },
    debug = {
      logging = false,
    },
  }
  return {
    options = opts,
    highlights = derive_colors(),
  }
end

--- Resolve (and update) any incompatible options based on the values of other options
--- e.g. in tabline only certain values are valid/certain options no longer make sense.
function Config:resolve(defaults)
  local user, hl = self.user.highlights, self.highlights
  if type(user) == "function" then hl = user(defaults) end

  self.highlights = utils.fold(function(accum, opts, hl_name)
    accum[hl_name] = highlights.translate_user_highlights(opts)
    return accum
  end, hl_table_to_color(hl))

  local indicator_icon = vim.tbl_get(self, "options", "indicator_icon")
  if indicator_icon then self.options.indicator = { icon = indicator_icon, style = "icon" } end

  if self:is_tabline() then
    local opts = defaults.options
    opts.sort_by = "tabs"
    if opts.show_tab_indicators then opts.show_tab_indicators = false end
    opts.close_command = utils.close_tab
    opts.right_mouse_command = "tabclose %d"
    opts.left_mouse_command = api.nvim_set_current_tabpage
  end
  return hl
end

---Generate highlight groups from user
---@param map table<string, table>
--- TODO: can this become part of a metatable for each highlight group so it is done at the point
---of usage
local function set_highlight_names(map)
  for name, opts in pairs(map) do
    opts.hl_group = highlights.generate_name(name)
  end
end

---Add highlight groups for a group
---@param hls BufferlineHighlights
local function set_group_highlights(hls)
  for _, group in pairs(groups.get_all()) do
    local group_hl, name = group.highlight, group.name
    if group_hl and type(group_hl) == "table" then
      group_hl = highlights.translate_user_highlights(group_hl)
      local sep_name = fmt("%s_separator", name)
      local label_name = fmt("%s_label", name)
      local selected_name = fmt("%s_selected", name)
      local visible_name = fmt("%s_visible", name)
      hls[sep_name] = {
        fg = group_hl.fg or group_hl.sp or hls.group_separator.fg,
        bg = hls.fill.bg,
      }
      hls[label_name] = {
        fg = hls.fill.bg,
        bg = group_hl.fg or group_hl.sp or hls.group_separator.fg,
      }

      hls[name] = vim.tbl_extend("keep", group_hl, hls.buffer)
      hls[visible_name] = vim.tbl_extend("keep", group_hl, hls.buffer_visible)
      hls[selected_name] = vim.tbl_extend("keep", group_hl, hls.buffer_selected)

      hls[name].hl_group = highlights.generate_name(name)
      hls[sep_name].hl_group = highlights.generate_name(sep_name)
      hls[label_name].hl_group = highlights.generate_name(label_name)
      hls[visible_name].hl_group = highlights.generate_name(visible_name)
      hls[selected_name].hl_group = highlights.generate_name(selected_name)
    end
  end
end

--- Merge user config with defaults
--- @param quiet boolean? whether or not to validate the configuration
--- @return BufferlineConfig
function M.apply(quiet)
  local defaults = get_defaults()
  local resolved = config:resolve(defaults)
  if not quiet then config:validate(defaults, resolved) end
  config:merge(defaults)
  set_highlight_names(config.highlights)
  set_group_highlights(config.highlights)
  return config
end

---Keep track of a users config for use throughout the plugin as well as ensuring
---defaults are set. This is also so we can diff what the user set this is useful
---for setting the highlight groups etc. once this has been merged with the defaults
---@param conf BufferlineConfig?
function M.set(conf) config = Config:new(conf or {}) end

---Update highlight colours when the colour scheme changes by resetting the user config
---to what was initially passed in and reload the highlighting
function M.update_highlights()
  M.set(config.user)
  M.apply(true)
  return config
end

---Get the user's configuration or a key from it
---@param key string?
---@return BufferlineConfig?
---@overload fun(key: "options"): BufferlineOptions
---@overload fun(key: "highlights"): BufferlineHighlights
function M.get(key)
  if not config then return end
  return config[key] or config
end

--- This function is only intended for use in tests
---@private
---@diagnostic disable-next-line: cast-local-type
function M.__reset() config = nil end

return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})
