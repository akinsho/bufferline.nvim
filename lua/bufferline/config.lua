local M = {}

-- Ideally this plugin should generate a beautiful tabline a little similar
-- to what you would get on other editors. The aim is that the default should
-- be so nice it's what anyone using this plugin sticks with. It should ideally
-- work across any well designed colorscheme deriving colors automagically.
function M.get_defaults()
  local colors = require("bufferline/colors")
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
    options = {
      view = "default",
      numbers = "none",
      number_style = "superscript",
      buffer_close_icon = "",
      modified_icon = "●",
      close_icon = "",
      left_trunc_marker = "",
      right_trunc_marker = "",
      separator_style = "thin",
      tab_size = 18,
      max_name_length = 18,
      mappings = false,
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
    highlights = {
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
    },
  }
end

return M
