local M = {}

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

---@class DebugOpts
---@field logging boolean

---@class GroupOptions
---@field toggle_hidden_on_enter boolean re-open hidden groups on bufenter

---@class GroupOpts
---@field options GroupOptions
---@field items Group[]

---@alias BufferlineMode "'tabs'" | "'buffers'"

---@alias DiagnosticIndicator fun(count: number, level: number, errors: table<string, any>, ctx: table<string, any>): string

---@class BufferlineOptions
---@field public mode BufferlineMode
---@field public view string
---@field public debug DebugOpts
---@field public numbers string
---@field public buffer_close_icon string
---@field public modified_icon string
---@field public close_icon string
---@field public close_command string
---@field public custom_filter fun(buf: number, bufnums: number[]): boolean
---@field public left_mouse_command string | function
---@field public right_mouse_command string | function
---@field public middle_mouse_command string | function
---@field public indicator_icon string
---@field public left_trunc_marker string
---@field public right_trunc_marker string
---@field public separator_style string
---@field public name_formatter fun(path: string):string
---@field public tab_size number
---@field public max_name_length number
---@field public color_icons boolean
---@field public show_buffer_icons boolean
---@field public show_buffer_close_icons boolean
---@field public show_buffer_default_icon boolean
---@field public show_close_icon boolean
---@field public show_tab_indicators boolean
---@field public enforce_regular_tabs boolean
---@field public always_show_bufferline boolean
---@field public persist_buffer_sort boolean
---@field public max_prefix_length number
---@field public sort_by string
---@field public diagnostics boolean
---@field public diagnostics_indicator DiagnosticIndicator
---@field public diagnostics_update_in_insert boolean
---@field public offsets table[]
---@field public groups GroupOpts
---@field public themable boolean

---@class BufferlineHLGroup
---@field guifg string
---@field guibg string
---@field guisp string
---@field gui string
---@field hl string
---@field hl_name string

---@alias BufferlineHighlights table<string, BufferlineHLGroup>

---@class BufferlineConfig
---@field public options BufferlineOptions
---@field public highlights BufferlineHighlights
---@field private original BufferlineConfig original copy of user preferences

--- Convert highlights specified as tables to the correct existing colours
---@param map BufferlineHighlights
local function convert_highlights(map)
  if not map or vim.tbl_isempty(map) then
    return {}
  end
  -- we deep copy the highlights table as assigning the attributes
  -- will only pass the references so will mutate the original table otherwise
  local updated = vim.deepcopy(map)
  for hl, attributes in pairs(map) do
    for attribute, value in pairs(attributes) do
      if type(value) == "table" then
        if value.highlight and value.attribute then
          updated[hl][attribute] = colors.get_hex({
            name = value.highlight,
            attribute = value.attribute,
          })
        else
          updated[hl][attribute] = nil
          utils.notify(fmt("removing %s as it is not formatted correctly", hl), utils.W)
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
  self.original = vim.deepcopy(o)
  setmetatable(o, self)
  return o
end

---Combine user preferences with defaults preferring the user's own settings
---@param defaults BufferlineConfig
---@return BufferlineConfig
function Config:merge(defaults)
  assert(defaults and type(defaults) == "table", "A valid config table must be passed to merge")
  self.options = vim.tbl_deep_extend("keep", self.options or {}, defaults.options or {})

  self.highlights = vim.tbl_deep_extend(
    "force",
    defaults.highlights,
    -- convert highlight link syntax to resolved highlight colors
    convert_highlights(self.original.highlights)
  )
  return self
end

local deprecations = {
  mappings = {
    message = "please refer to the BufferLineGoToBuffer section of the README",
    pending = false,
  },
  number_style = {
    message = "please specify 'numbers' as a function instead. See :h bufferline-numbers for details",
    pending = true,
  },
}

---@param options BufferlineOptions
local function handle_deprecations(options)
  if not options then
    return
  end
  for key, _ in pairs(options) do
    local deprecation = deprecations[key]
    if deprecation then
      vim.schedule(function()
        local timeframe = deprecation.pending and "will be" or "has been"
        utils.notify(fmt("'%s' %s deprecated: %s", key, timeframe, deprecation.message), utils.W)
      end)
    end
  end
end

---Ensure the user has only specified highlight groups that exist
---@param defaults BufferlineConfig
function Config:validate(defaults)
  handle_deprecations(self.options)
  if self.highlights then
    local incorrect = {}
    for k, _ in pairs(self.highlights) do
      if not defaults.highlights[k] then
        table.insert(incorrect, k)
      end
    end
    -- Don't continue if there are no incorrect highlights
    if vim.tbl_isempty(incorrect) then
      return
    end
    local is_plural = #incorrect > 1
    local verb = is_plural and " are " or " is "
    local article = is_plural and " " or " a "
    local object = is_plural and " groups. " or " group. "
    local msg = table.concat({
      table.concat(incorrect, ", "),
      verb,
      "not",
      article,
      "valid highlight",
      object,
      "Please check the README for all valid highlights",
    })
    utils.notify(msg, utils.E)
  end
end

function Config:mode()
  return self.options.mode
end

function Config:is_bufferline()
  return self:mode() == "buffers"
end

function Config:is_tabline()
  return self:mode() == "tabs"
end

local nightly = vim.fn.has("nvim-0.6") > 0

---Derive the colors for the bufferline
---@return BufferlineHighlights
local function derive_colors()
  local hex = colors.get_hex
  local shade = colors.shade_color

  local comment_fg = hex({
    name = "Comment",
    attribute = "fg",
    fallback = { name = "Normal", attribute = "fg" },
  })

  local normal_fg = hex({ name = "Normal", attribute = "fg" })
  local normal_bg = hex({ name = "Normal", attribute = "bg" })
  local string_fg = hex({ name = "String", attribute = "fg" })

  local error_hl = nightly and "DiagnosticError" or "LspDiagnosticsDefaultError"
  local warning_hl = nightly and "DiagnosticWarn" or "LspDiagnosticsDefaultWarning"
  local info_hl = nightly and "DiagnosticInfo" or "LspDiagnosticsDefaultInformation"
  local hint_hl = nightly and "DiagnosticHint" or "LspDiagnosticsDefaultHint"

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

  return {
    fill = {
      guifg = comment_fg,
      guibg = separator_background_color,
    },
    group_separator = {
      guifg = comment_fg,
      guibg = separator_background_color,
    },
    group_label = {
      guibg = comment_fg,
      guifg = separator_background_color,
    },
    tab = {
      guifg = comment_fg,
      guibg = background_color,
    },
    tab_selected = {
      guifg = tabline_sel_bg,
      guibg = normal_bg,
    },
    tab_close = {
      guifg = comment_fg,
      guibg = background_color,
    },
    close_button = {
      guifg = comment_fg,
      guibg = background_color,
    },
    close_button_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    close_button_selected = {
      guifg = normal_fg,
      guibg = normal_bg,
    },
    background = {
      guifg = comment_fg,
      guibg = background_color,
    },
    buffer = {
      guifg = comment_fg,
      guibg = background_color,
    },
    buffer_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    buffer_selected = {
      guifg = normal_fg,
      guibg = normal_bg,
      gui = "bold,italic",
    },
    numbers = {
      guifg = comment_fg,
      guibg = background_color,
    },
    numbers_selected = {
      guifg = normal_fg,
      guibg = normal_bg,
      gui = "bold,italic",
    },
    numbers_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    diagnostic = {
      guifg = comment_diagnostic_fg,
      guibg = background_color,
    },
    diagnostic_visible = {
      guifg = comment_diagnostic_fg,
      guibg = visible_bg,
    },
    diagnostic_selected = {
      guifg = normal_diagnostic_fg,
      guibg = normal_bg,
      gui = "bold,italic",
    },
    hint = {
      guifg = comment_fg,
      guisp = hint_fg,
      guibg = background_color,
    },
    hint_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    hint_selected = {
      guifg = hint_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = hint_fg,
    },
    hint_diagnostic = {
      guifg = comment_diagnostic_fg,
      guisp = hint_diagnostic_fg,
      guibg = background_color,
    },
    hint_diagnostic_visible = {
      guifg = comment_diagnostic_fg,
      guibg = visible_bg,
    },
    hint_diagnostic_selected = {
      guifg = hint_diagnostic_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = hint_diagnostic_fg,
    },
    info = {
      guifg = comment_fg,
      guisp = info_fg,
      guibg = background_color,
    },
    info_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    info_selected = {
      guifg = info_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = info_fg,
    },
    info_diagnostic = {
      guifg = comment_diagnostic_fg,
      guisp = info_diagnostic_fg,
      guibg = background_color,
    },
    info_diagnostic_visible = {
      guifg = comment_diagnostic_fg,
      guibg = visible_bg,
    },
    info_diagnostic_selected = {
      guifg = info_diagnostic_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = info_diagnostic_fg,
    },
    warning = {
      guifg = comment_fg,
      guisp = warning_fg,
      guibg = background_color,
    },
    warning_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    warning_selected = {
      guifg = warning_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = warning_fg,
    },
    warning_diagnostic = {
      guifg = comment_diagnostic_fg,
      guisp = warning_diagnostic_fg,
      guibg = background_color,
    },
    warning_diagnostic_visible = {
      guifg = comment_diagnostic_fg,
      guibg = visible_bg,
    },
    warning_diagnostic_selected = {
      guifg = warning_diagnostic_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = warning_diagnostic_fg,
    },
    error = {
      guifg = comment_fg,
      guibg = background_color,
      guisp = error_fg,
    },
    error_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    error_selected = {
      guifg = error_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = error_fg,
    },
    error_diagnostic = {
      guifg = comment_diagnostic_fg,
      guibg = background_color,
      guisp = error_diagnostic_fg,
    },
    error_diagnostic_visible = {
      guifg = comment_diagnostic_fg,
      guibg = visible_bg,
    },
    error_diagnostic_selected = {
      guifg = error_diagnostic_fg,
      guibg = normal_bg,
      gui = "bold,italic",
      guisp = error_diagnostic_fg,
    },
    modified = {
      guifg = string_fg,
      guibg = background_color,
    },
    modified_visible = {
      guifg = string_fg,
      guibg = visible_bg,
    },
    modified_selected = {
      guifg = string_fg,
      guibg = normal_bg,
    },
    duplicate_selected = {
      guifg = duplicate_color,
      gui = "italic",
      guibg = normal_bg,
    },
    duplicate_visible = {
      guifg = duplicate_color,
      gui = "italic",
      guibg = visible_bg,
    },
    duplicate = {
      guifg = duplicate_color,
      gui = "italic",
      guibg = background_color,
    },
    separator_selected = {
      guifg = separator_background_color,
      guibg = normal_bg,
    },
    separator_visible = {
      guifg = separator_background_color,
      guibg = visible_bg,
    },
    separator = {
      guifg = separator_background_color,
      guibg = background_color,
    },
    indicator_selected = {
      guifg = tabline_sel_bg,
      guibg = normal_bg,
    },
    pick_selected = {
      guifg = error_fg,
      guibg = normal_bg,
      gui = "bold,italic",
    },
    pick_visible = {
      guifg = error_fg,
      guibg = visible_bg,
      gui = "bold,italic",
    },
    pick = {
      guifg = error_fg,
      guibg = background_color,
      gui = "bold,italic",
    },
  }
end

-- Ideally this plugin should generate a beautiful tabline a little similar
-- to what you would get on other editors. The aim is that the default should
-- be so nice it's what anyone using this plugin sticks with. It should ideally
-- work across any well designed colorscheme deriving colors automagically.
---@return BufferlineConfig
local function get_defaults()
  return {
    ---@type BufferlineOptions
    options = {
      mode = "buffers",
      themable = true, -- whether or not bufferline highlights can be overriden externally
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
      indicator_icon = "▎",
      left_trunc_marker = "",
      right_trunc_marker = "",
      separator_style = "thin",
      name_formatter = nil,
      tab_size = 18,
      max_name_length = 18,
      mappings = false,
      color_icons = true,
      show_buffer_icons = true,
      show_buffer_close_icons = true,
      show_buffer_default_icon = true,
      show_close_icon = true,
      show_tab_indicators = true,
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
      debug = {
        logging = false,
      },
    },
    highlights = derive_colors(),
  }
end

--- Resolve/change any incompatible options based on the values of other options
--- e.g. in tabline only certain values are valid/certain options no longer make sense.
function Config:resolve()
  local is_tabline = self:is_tabline()
  -- Don't show tab indicators in tabline mode
  if is_tabline and self.options.show_tab_indicators then
    self.options.show_tab_indicators = false
  end
  -- If the sort by mechanism is "tabs" but the user is in tabline mode
  -- then the id will be that of the tabs so sort by should be id i.e. "tabs" sort
  -- is redundant in tabs mode
  if is_tabline and self.options.sort_by == "tabs" then
    self.options.sort_by = "id"
  end
  if is_tabline then
    self.options.close_command = "tabclose %d"
    self.options.right_mouse_command = "tabclose %d"
    self.options.left_mouse_command = vim.api.nvim_set_current_tabpage
  end
end

---Generate highlight groups from user
---@param map table<string, table>
--- TODO: can this become part of a metatable for each highlight group so it is done at the point
---of usage
local function add_highlight_groups(map)
  for name, tbl in pairs(map) do
    highlights.add_group(name, tbl)
  end
end

--- Merge user config with defaults
--- @return BufferlineConfig
function M.apply()
  local defaults = get_defaults()
  config:validate(defaults)
  config:merge(defaults)
  config:resolve()
  -- TODO: Can setting up of group highlights be constrained to the config module
  groups.setup(config)
  add_highlight_groups(config.highlights)
  return config
end

---Keep track of a users config for use throughout the plugin as well as ensuring
---defaults are set. This is also so we can diff what the user set this is useful
---for setting the highlight groups etc. once this has been merged with the defaults
---@param conf BufferlineConfig
function M.set(conf)
  config = Config:new(conf or {})
end

---Update highlight colours when the colour scheme changes
function M.update_highlights()
  config:merge({ highlights = derive_colors() })
  groups.reset_highlights(config.highlights)
  add_highlight_groups(config.highlights)
  return config
end

---Get the user's configuration or a key from it
---@param key string?
---@return BufferlineConfig
---@overload fun(key: '"options"'): BufferlineOptions
---@overload fun(key: '"highlights"'): BufferlineHighlights
function M.get(key)
  if not config then
    return
  end
  return config[key] or config
end

--- This function is only intended for use in tests
---@private
function M.__reset()
  config = nil
end

return setmetatable(M, {
  __index = function(_, k)
    return config[k]
  end,
})
