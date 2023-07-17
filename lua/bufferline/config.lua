local M = {}

local api = vim.api
local fmt = string.format
local lazy = require("bufferline.lazy")
local groups = lazy.require("bufferline.groups") ---@module "bufferline.groups"
local utils = lazy.require("bufferline.utils") ---@module "bufferline.utils"
local highlights = lazy.require("bufferline.highlights") ---@module "bufferline.highlights"
local colors = lazy.require("bufferline.colors") ---@module "bufferline.colors"
local constants = lazy.require("bufferline.constants") ---@module "bufferline.colors"

---@enum bufferline.StylePreset
local PRESETS = {
  default = 1,
  minimal = 2,
  no_bold = 3,
  no_italic = 4,
}

---The local class instance of the merged user's configuration
---this includes all default values and highlights filled out
---@type bufferline.Config
local config = {}

---The class definition for the user configuration
---@type bufferline.Config
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
---@param defaults bufferline.Config
---@return bufferline.Config
function Config:merge(defaults)
  assert(defaults and type(defaults) == "table", "A valid config table must be passed to merge")
  self.options = vim.tbl_deep_extend("force", defaults.options, self.options or {})
  self.highlights = vim.tbl_deep_extend("force", defaults.highlights, self.highlights or {})
  return self
end

local deprecations = {
  show_buffer_default_icon = {
    name = "show_buffer_default_icon",
    alternative = "get_element_icon = function(buf) return require('nvim-web-devicons').get_icon(..., {default = false})",
    version = "4.0.0",
  },
}

---@param options bufferline.Options
local function validate_user_options(options)
  if not options then return end
  for key, _ in pairs(options) do
    local item = deprecations[key]
    if item then vim.schedule(function() vim.deprecate(item.name, item.alternative, item.version, "bufferline") end) end
  end
end

---@param options bufferline.Options
---@return {[string]: table}[]
local function get_offset_highlights(options)
  if not options or not options.offsets then return {} end
  return utils.fold(function(accum, offset, i)
    if offset.highlight and type(offset.highlight) == "table" then accum[fmt("offset_%d", i)] = offset.highlight end
    return accum
  end, options.offsets)
end

---@param options bufferline.Options
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
  local incorrect = { invalid_hl = {} }

  local offset_highlights = get_offset_highlights(opts)
  local group_highlights = get_group_highlights(opts)
  local all_hls = vim.tbl_extend("force", {}, hls, offset_highlights, group_highlights)

  for k, _ in pairs(all_hls) do
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
end

--- Check that the user has not placed setting in the wrong tables
---@param conf bufferline.UserConfig
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
---@param defaults bufferline.Config
---@param resolved bufferline.Highlights
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
---@param preset bufferline.StylePreset | bufferline.StylePreset[]
---@return bufferline.Highlights
local function derive_colors(preset)
  local hex = colors.get_color
  local tint = colors.shade_color
  if type(preset) ~= "table" then preset = { preset } end
  local is_minimal = vim.tbl_contains(preset, PRESETS.minimal)
  local italic = not vim.tbl_contains(preset, PRESETS.no_italic)
  local bold = not vim.tbl_contains(preset, PRESETS.no_bold)

  local comment_fg = hex({
    name = "Comment",
    attribute = "fg",
    fallback = { name = "Normal", attribute = "fg" },
  })

  local normal_fg = hex({ name = "Normal", attribute = "fg" })
  local normal_bg = hex({ name = "Normal", attribute = "bg" })
  local string_fg = hex({ name = "String", attribute = "fg" })

  local error_fg = hex({
    name = "DiagnosticError", -- diagnostic with text highlight
    attribute = "fg",
    fallback = {
      name = "DiagnosticError", -- diagnostic with underline highlight
      attribute = "sp",
      fallback = {
        name = "Error",
        attribute = "fg",
      },
    },
  })

  local warning_fg = hex({
    name = "DiagnosticWarn",
    attribute = "fg",
    fallback = {
      name = "DiagnosticWarn",
      attribute = "sp",
      fallback = {
        name = "WarningMsg",
        attribute = "fg",
      },
    },
  })

  local info_fg = hex({
    name = "DiagnosticInfo",
    attribute = "fg",
    fallback = {
      name = "DiagnosticInfo",
      attribute = "sp",
      fallback = {
        name = "Normal",
        attribute = "fg",
      },
    },
  })

  local hint_fg = hex({
    name = "DiagnosticHint",
    attribute = "fg",
    fallback = {
      name = "DiagnosticHint",
      attribute = "sp",
      fallback = {
        name = "Directory",
        attribute = "fg",
      },
    },
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

  local duplicate_color = tint(comment_fg, -5)
  local visible_bg = is_minimal and normal_bg or tint(normal_bg, -8)
  local visible_fg = is_minimal and tint(normal_fg, -30) or comment_fg
  local separator_background_color = is_minimal and normal_bg or tint(normal_bg, separator_shading)
  local background_color = is_minimal and normal_bg or tint(normal_bg, background_shading)

  -- diagnostic colors by default are a few shades darker
  local normal_diagnostic_fg = tint(normal_fg, diagnostic_shading)
  local comment_diagnostic_fg = tint(comment_fg, diagnostic_shading)
  local hint_diagnostic_fg = tint(hint_fg, diagnostic_shading)
  local info_diagnostic_fg = tint(info_fg, diagnostic_shading)
  local warning_diagnostic_fg = tint(warning_fg, diagnostic_shading)
  local error_diagnostic_fg = tint(error_fg, diagnostic_shading)

  local indicator_style = vim.tbl_get(config, "user", "options", "indicator", "style")
  local has_underline_indicator = indicator_style == "underline"

  local underline_sp = has_underline_indicator and tabline_sel_bg or nil

  local trunc_marker_fg = comment_fg
  local trunc_marker_bg = separator_background_color

  return {
    trunc_marker = {
      fg = trunc_marker_fg,
      bg = trunc_marker_bg,
    },
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
      bold = is_minimal and bold,
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
      fg = visible_fg,
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
      fg = visible_fg,
      bg = visible_bg,
      italic = is_minimal and italic,
      bold = is_minimal and bold,
    },
    buffer_selected = {
      fg = normal_fg,
      bg = normal_bg,
      bold = bold,
      italic = italic,
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
      bold = bold,
      italic = italic,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    numbers_visible = {
      fg = visible_fg,
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
      bold = bold,
      italic = italic,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    hint = {
      fg = comment_fg,
      sp = hint_fg,
      bg = background_color,
    },
    hint_visible = {
      fg = visible_fg,
      bg = visible_bg,
      italic = is_minimal and italic,
      bold = is_minimal and bold,
    },
    hint_selected = {
      fg = hint_fg,
      bg = normal_bg,
      bold = bold,
      italic = italic,
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
      bold = bold,
      italic = italic,
      underline = has_underline_indicator,
      sp = underline_sp or hint_diagnostic_fg,
    },
    info = {
      fg = comment_fg,
      sp = info_fg,
      bg = background_color,
    },
    info_visible = {
      fg = visible_fg,
      bg = visible_bg,
      italic = is_minimal and italic,
      bold = is_minimal and bold,
    },
    info_selected = {
      fg = info_fg,
      bg = normal_bg,
      bold = bold,
      italic = italic,
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
      bold = bold,
      italic = italic,
      underline = has_underline_indicator,
      sp = underline_sp or info_diagnostic_fg,
    },
    warning = {
      fg = comment_fg,
      sp = warning_fg,
      bg = background_color,
    },
    warning_visible = {
      fg = visible_fg,
      bg = visible_bg,
      italic = is_minimal and italic,
      bold = is_minimal and bold,
    },
    warning_selected = {
      fg = warning_fg,
      bg = normal_bg,
      bold = bold,
      italic = italic,
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
      bold = bold,
      italic = italic,
      underline = has_underline_indicator,
      sp = underline_sp or warning_diagnostic_fg,
    },
    error = {
      fg = comment_fg,
      bg = background_color,
      sp = error_fg,
    },
    error_visible = {
      fg = visible_fg,
      bg = visible_bg,
      italic = is_minimal and italic,
      bold = is_minimal and bold,
    },
    error_selected = {
      fg = error_fg,
      bg = normal_bg,
      bold = bold,
      italic = italic,
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
      bold = bold,
      italic = italic,
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
      italic = italic,
      bg = normal_bg,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    duplicate_visible = {
      fg = duplicate_color,
      italic = italic,
      bg = visible_bg,
    },
    duplicate = {
      fg = duplicate_color,
      italic = italic,
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
      bold = bold,
      italic = italic,
      sp = underline_sp,
      underline = has_underline_indicator,
    },
    pick_visible = {
      fg = error_fg,
      bg = visible_bg,
      bold = bold,
      italic = italic,
    },
    pick = {
      fg = error_fg,
      bg = background_color,
      bold = bold,
      italic = italic,
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
---@return bufferline.Config
local function get_defaults()
  local preset = vim.tbl_get(config, "user", "options", "style_preset") --[[@as bufferline.StylePreset]]
  ---@type bufferline.Options
  local opts = {
    mode = "buffers",
    themable = true, -- whether or not bufferline highlights can be overridden externally
    style_preset = preset,
    numbers = "none",
    buffer_close_icon = "",
    modified_icon = "●",
    close_icon = "",
    close_command = "bdelete! %d",
    left_mouse_command = "buffer %d",
    right_mouse_command = "bdelete! %d",
    middle_mouse_command = nil,
    -- U+2590 ▐ Right half block, this character is right aligned so the
    -- background highlight doesn't appear in the middle
    -- alternatives:  right aligned => ▕ ▐ ,  left aligned => ▍
    indicator = { icon = constants.indicator, style = "icon" },
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
    get_element_icon = nil,
    show_close_icon = true,
    show_tab_indicators = true,
    show_duplicate_prefix = true,
    enforce_regular_tabs = false,
    always_show_bufferline = true,
    persist_buffer_sort = true,
    move_wraps_at_ends = false,
    max_prefix_length = 15,
    sort_by = "id",
    diagnostics = false,
    diagnostics_indicator = nil,
    diagnostics_update_in_insert = true,
    offsets = {},
    groups = { items = {}, options = { toggle_hidden_on_enter = true } },
    hover = { enabled = false, reveal = {}, delay = 200 },
    debug = { logging = false },
  }
  return { options = opts, highlights = derive_colors(opts.style_preset) }
end

--- Convert highlights specified as tables to the correct existing colours
---@param map bufferline.Highlights
local function resolve_user_highlight_links(map)
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

--- Resolve (and update) any incompatible options based on the values of other options
--- e.g. in tabline only certain values are valid/certain options no longer make sense.
function Config:resolve(defaults)
  local user, hl = self.user.highlights, self.highlights
  if type(user) == "function" then hl = user(defaults) end
  self.highlights = resolve_user_highlight_links(hl)

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
---@param map {[string]: {fg: string, bg: string}}
--- TODO: can this become part of a metatable for each highlight group so it is done at the point
---of usage
local function set_highlight_names(map)
  for name, opts in pairs(map) do
    opts.hl_group = highlights.generate_name(name)
  end
end

---Add highlight groups for a group
---@param hls bufferline.Highlights
local function set_group_highlights(hls)
  for _, group in pairs(groups.get_all()) do
    local group_hl, name = group.highlight, group.name
    if group_hl and type(group_hl) == "table" then
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
--- @return bufferline.Config
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
---@param c bufferline.UserConfig?
function M.setup(c) config = Config:new(c or {}) end

---Update highlight colours when the colour scheme changes by resetting the user config
---to what was initially passed in and reload the highlighting
function M.update_highlights()
  M.setup(config.user)
  M.apply(true)
  return config
end

---Get the user's configuration or a key from it
---@return bufferline.Config?
function M.get()
  if config then return config end
end

if _G.__TEST then
  function M.__reset() config = nil end
end

M.STYLE_PRESETS = PRESETS

return setmetatable(M, {
  __index = function(_, k) return config[k] end,
})
