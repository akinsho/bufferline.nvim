local colors = require "bufferline/colors"

local M = {}

-- Ideally this plugin should generate a beautiful tabline a little similar
-- to what you would get on other editors. The aim is that the default should
-- be so nice it's what anyone using this plugin sticks with. It should ideally
-- work across any well designed colorscheme deriving colors automagically.
function M.get_defaults()
  local comment_fg = colors.get_hex("Comment", "fg")
  local normal_fg = colors.get_hex("Normal", "fg")
  local normal_bg = colors.get_hex("Normal", "bg")
  local string_fg = colors.get_hex("String", "fg")
  local error_fg = colors.get_hex("Error", "fg")

  local tabline_sel_bg = colors.get_hex("TabLineSel", "bg")
  if not tabline_sel_bg == "none" then
    tabline_sel_bg = colors.get_hex("WildMenu", "bg")
  end

  -- If the colorscheme is bright we shouldn't do as much shading
  -- as this makes light color schemes harder to read
  local is_bright_background = colors.color_is_bright(normal_bg)
  local separator_shading = is_bright_background and -20 or -45
  local background_shading = is_bright_background and -12 or -25

  local duplicate_color = colors.shade_color(comment_fg, -5)
  local separator_background_color =
    colors.shade_color(normal_bg, separator_shading)
  local background_color = colors.shade_color(normal_bg, background_shading)

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
      enforce_regular_tabs = false,
      always_show_bufferline = true,
      sort_by = "default"
    },
    highlights = {
      bufferline_tab = {
        guifg = comment_fg,
        guibg = background_color
      },
      bufferline_tab_selected = {
        guifg = tabline_sel_bg,
        guibg = normal_bg
      },
      bufferline_selected_separator = {
        guifg = separator_background_color,
        guibg = normal_bg
      },
      bufferline_tab_close = {
        guifg = comment_fg,
        guibg = background_color
      },
      bufferline_fill = {
        guifg = comment_fg,
        guibg = separator_background_color
      },
      bufferline_background = {
        guifg = comment_fg,
        guibg = background_color
      },
      bufferline_buffer_inactive = {
        guifg = comment_fg,
        guibg = normal_bg
      },
      bufferline_modified = {
        guifg = string_fg,
        guibg = background_color
      },
      bufferline_duplicate = {
        guifg = duplicate_color,
        gui = "italic",
        guibg = normal_bg
      },
      bufferline_duplicate_inactive = {
        guifg = duplicate_color,
        gui = "italic",
        guibg = background_color
      },
      bufferline_modified_inactive = {
        guifg = string_fg,
        guibg = normal_bg
      },
      bufferline_modified_selected = {
        guifg = string_fg,
        guibg = normal_bg
      },
      bufferline_separator = {
        guifg = separator_background_color,
        guibg = background_color
      },
      bufferline_selected_indicator = {
        guifg = tabline_sel_bg,
        guibg = normal_bg
      },
      bufferline_selected = {
        guifg = normal_fg,
        guibg = normal_bg,
        gui = "bold,italic"
      },
      bufferline_pick = {
        guifg = error_fg,
        guibg = normal_bg,
        gui = "bold,italic"
      },
      bufferline_pick_inactive = {
        guifg = error_fg,
        guibg = background_color,
        gui = "bold,italic"
      }
    }
  }
end

return M
