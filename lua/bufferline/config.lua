local M = {}

local _config = {}
local _user_config = {}

---Ensure the user has only specified highlight groups that exist
---@param prefs table
---@param defaults table
local function validate_config(prefs, defaults)
  if prefs and prefs.highlights then
    local incorrect = {}
    for k, _ in pairs(prefs.highlights) do
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
    require("bufferline.utils").echomsg(msg, "WarningMsg")
  end
end

--- Convert highlights specified as tables to the correct existing colours
---@param prefs table
local function convert_hl_tables(prefs)
  if not prefs or not prefs.highlights or vim.tbl_isempty(prefs.highlights) then
    return
  end
  for hl, attributes in pairs(prefs.highlights) do
    for attribute, value in pairs(attributes) do
      if type(value) == "table" then
        if value.highlight and value.attribute then
          prefs.highlights[hl][attribute] = require("bufferline.colors").get_hex({
            name = value.highlight,
            attribute = value.attribute,
          })
        else
          prefs.highlights[hl][attribute] = nil
          print(string.format("removing %s as it is not formatted correctly", hl))
        end
      end
    end
  end
end

---Merge user preferences with defaults
---@param defaults table
---@param preferences table
---@return table
local function merge(defaults, preferences)
  -- Combine user preferences with defaults preferring the user's own settings
  if preferences and type(preferences) == "table" then
    preferences = vim.tbl_deep_extend("force", defaults, preferences)
  end
  return preferences
end

local function derive_colors()
  local colors = require("bufferline.colors")
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

  local error_fg = hex({
    name = "LspDiagnosticsDefaultError",
    attribute = "fg",
    fallback = { name = "Error", attribute = "fg" },
  })

  local warning_fg = hex({
    name = "LspDiagnosticsDefaultWarning",
    attribute = "fg",
    fallback = { name = "WarningMsg", attribute = "fg" },
  })

  local info_fg = hex({
    name = "LspDiagnosticsDefaultInformation",
    attribute = "fg",
    fallback = { name = "Normal", attribute = "fg" },
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
  local info_diagnostic_fg = shade(info_fg, diagnostic_shading)
  local warning_diagnostic_fg = shade(warning_fg, diagnostic_shading)
  local error_diagnostic_fg = shade(error_fg, diagnostic_shading)

  return {
    fill = {
      guifg = comment_fg,
      guibg = separator_background_color,
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
    buffer_visible = {
      guifg = comment_fg,
      guibg = visible_bg,
    },
    buffer_selected = {
      guifg = normal_fg,
      guibg = normal_bg,
      gui = "bold,italic",
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
local function get_defaults()
  return {
    options = {
      view = "default",
      numbers = "none",
      number_style = "superscript",
      buffer_close_icon = "",
      modified_icon = "●",
      close_icon = "",
      close_command = "bdelete! %d",
      left_mouse_command = "buffer %d",
      right_mouse_command = "bdelete! %d",
      middle_mouse_command = nil,
      -- U+2590 ▐ Right half block, this character is right aligned so the
      -- background highlight doesn't appear in th middle
      -- alternatives:  right aligned => ▕ ▐ ,  left aligned => ▍
      indicator_icon = "▎",
      left_trunc_marker = "",
      right_trunc_marker = "",
      separator_style = "thin",
      tab_size = 18,
      max_name_length = 18,
      mappings = false,
      show_buffer_icons = true,
      show_buffer_close_icons = true,
      show_close_icon = true,
      show_tab_indicators = true,
      enforce_regular_tabs = false,
      always_show_bufferline = true,
      persist_buffer_sort = true,
      max_prefix_length = 15,
      sort_by = "default",
      diagnostics = false,
      diagnostic_indicator = nil,
      offsets = {},
    },
    highlights = derive_colors(),
  }
end

---Generate highlight groups from user
---@param user_colors table<string, table>
--- TODO can this become part of a metatable for each highlight group so it is done at the time
local function add_highlight_groups(user_colors)
  for name, tbl in pairs(user_colors) do
    -- convert 'bufferline_value' to 'BufferlineValue' -> snake to pascal
    local formatted = "BufferLine" .. name:gsub("_(.)", name.upper):gsub("^%l", string.upper)
    tbl.hl_name = formatted
    tbl.hl = require("bufferline.highlights").hl(formatted)
  end
end

---Keep track of a users config for use throughout the plugin as well as ensuring
---defaults are set
---@param user_config table
---@return table
function M.set(user_config)
  user_config = user_config or {}
  local defaults = get_defaults()
  validate_config(user_config, defaults)
  convert_hl_tables(user_config)
  --- Store a reference to the original user_config so we can diff what the user set
  --- this is useful for setting the highlight groups etc. once this has been merged with the
  --- defaults
  _user_config = user_config
  _config = merge(defaults, user_config)
  add_highlight_groups(_config.highlights)
  return _config
end

---Update highlight colours when the colour scheme changes
function M.update_highlights()
  _config.highlights = merge(derive_colors(), _user_config.highlights or {})
  add_highlight_groups(_config.highlights)
  return _config
end

---Get the user's configuration or a key from it
---@param key string?
---@return any
function M.get(key)
  if key and type(key) == "string" then
    return _config[key]
  end
  return _config
end

--- This function is only intended for use in tests
---@private
function M.__reset()
  _config = {}
  _user_config = {}
end

return M
