# nvim-bufferline.lua

A _snazzy_ 💅 buffer line (with minimal tab integration) for Neovim built using **lua**.

![Bufferline_with_close](./screenshots/bufferline.png "Bufferline with close icons")

![Bufferline screenshot](./screenshots/bufferline_with_numbers.png "Nvim Bufferline")

This plugin shamelessly attempts to emulate the aesthetics of GUI text editors/Doom Emacs.

**Status: 🚧 Alpha**

## Features

- Colours derived from colorscheme where possible, should appear similar in most cases
- Option to show buffer numbers
- Close icons for closing individual buffers
- Modified symbol

<img src="./screenshots/bufferline_with_modified.png" alt="modified icon" width="350px" />

## Requirements

- Nightly nvim
- A patched font (see [nerd fonts](https://github.com/ryanoasis/nerd-fonts))

## Installation

Super early days there might be some breaking changes, if you use this
without configuring it this shouldn't affect you too much.

```vim
Plug 'ryanoasis/vim-devicons' " Optional but recommended
Plug 'Akin909/nvim-bufferline.lua'
```

## Usage

```vim
" In your init.vim AFTER loading plugins
lua require'bufferline'.setup()
```

## Warning
This plugin relies on some basic highlights being set by your colour scheme
i.e. `Normal`, `String`, `TabLineSel` (`WildMenu` as fallback), `Comment`.
It's unlikely to work with all colour schemes, which is not something I will fix tbh.
You can either try manually overriding the colours or manually creating these highlight groups
before loading this plugin.

If the contrast in your colour scheme is too high, think all black colour scheme, this is
plugin won't create a nice tabline.

## Why another buffer line plugin?

1. I was looking for an excuse to play with **lua** and learn to create a plugin with it for Neovim.
2. I wanted to add some tweaks to my buffer line and didn't want to figure out a bunch of `vimscript` in some other plugin.

### Why make it public rather than as part of your `init.vim`

🤷 figured someone else might like the aesthetic. Don't make me regret this...

## Goals

- [x] Make it snazzy
- [x] Maintain general appearance across various colour schemes. Tested with:
  - `one.vim`
  - `night-owl.vim`
  - `vim-monokai-tasty`

### Future Goals

- [ ] Show LSP diagnostics in bufferline so it's clear which buffers have errors
- [ ] A _few_ different configuration options for file names
- [x] Show only the buffers relevant/open in a specific tab as a configurable setting

## Non-goals

- Supporting vim please don't ask. The whole point was to create a lua plugin. If vim ends up supporting lua in the _same_ way then maybe.
- Add every possible feature under the sun ☀, to appease everybody.
- Create and maintain a monolith 😓.

## Todo

- [x] Expose user configuration
- [ ] Fix truncation happening too early i.e. available width reported incorrectly
- [x] Fix modified highlight colouring
- [x] Show tabs
- [x] Handle keeping active buffer always in view
- [x] Show remainder marker as <- or -> depending on where truncation occurred
- [x] Fix current buffer highlight disappearing when inside ignored buffer
- [x] Dynamically set styling to appear consistent across colour schemes
- [x] Buffer label truncation
- [ ] Highlight file type icons if possible see [for example](https://github.com/weirongxu/coc-explorer/blob/59bd41f8fffdc871fbd77ac443548426bd31d2c3/src/icons.nerdfont.json#L2)

## Configuration

```vim
lua require'bufferline'.setup{
  options = {
    view = "multiwindow" | "default",
    numbers = "none" | "ordinal" | "buffer_id",
    number_style = "superscript" | "",
    mappings = true | false,
    close_icon = "x"
    max_name_length = 20,
    show_buffer_close_icons = true | false,
    separator_style = "thick" | "thin"
  }
}
```

### Multiwindow mode (inspired by [`vem-tabline`](https://github.com/pacha/vem-tabline))

When this mode is active, for layouts of multiple windows in the tabpage,
only the buffers that are displayed in those windows are listed in the
tabline. That only applies to multi-window layouts, if there is only one
window in the tabpage, all buffers are listed.

### Mappings

If the `mappings` option is set to `true`. `<leader>`1-10 mappings will
be created to navigate the first to the tenth buffer in the bufferline.
**This is false by default**. If you'd rather map these yourself, use:

```vim
nnoremap mymap :lua require"bufferline".go_to_buffer(num)<CR>
```

### Highlight configuration

This plugin is designed to work automatically, deriving colours from the user's theme,
but if you must...

```vim
lua require'bufferline'.setup{
  highlights = {
    bufferline_tab = {
      guifg = comment_fg,
      guibg = normal_bg,
    };
    bufferline_tab_selected = {
      guifg = comment_fg,
      guibg = tabline_sel_bg,
    };
    bufferline_buffer = {
      guifg = comment_fg,
      guibg = custom_bg,
    };
    bufferline_buffer_inactive = {
      guifg = comment_fg,
      guibg = normal_bg,
    };
    bufferline_modified = {
      guifg = diff_add_fg,
      guibg = "none"
    };
    bufferline_separator = {
      guibg = custom_bg,
    };
    bufferline_selected = {
      guifg = normal_fg,
      guibg = normal_bg,
      gui = "bold,italic",
    };
  };
}
```
