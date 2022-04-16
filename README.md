[![Run tests](https://github.com/akinsho/bufferline.nvim/actions/workflows/test.yaml/badge.svg)](https://github.com/akinsho/bufferline.nvim/actions/workflows/test.yaml)

<h1 align="center">
  bufferline.nvim
</h1>

<p align="center">A <i>snazzy</i> 💅 buffer line (with tabpage integration) for Neovim built using <b>lua</b>.</p>

![Demo GIF](https://user-images.githubusercontent.com/22454918/111992693-9c6a9b00-8b0d-11eb-8c39-19db58583061.gif)

This plugin shamelessly attempts to emulate the aesthetics of GUI text editors/Doom Emacs.
It was inspired by a screenshot of DOOM Emacs using [centaur tabs](https://github.com/ema2159/centaur-tabs).

# Table of Contents

- [Features](#features)
  - [Alternate styling](#alternate-styling)
  - [Tabpages mode](#tabpages-mode)
  - [LSP error indicators](#lsp-error-indicators)
  - [Buffer groups](#buffer-groups)
  - [Sidebar offset](#sidebar-offset)
  - [Buffer numbers](#buffer-numbers)
  - [Buffer pick](#buffer-pick)
  - [Unique buffer names](#unique-buffer-names)
  - [Close icons](#close-icons)
  - [Buffer re-ordering](#buffer-re-ordering)
  - [Pinning buffers](#pinning-buffers)
- [Requirements](#requirements)
- [Installation](#installation)
- [Caveats](#caveats)
- [Usage](#usage)
- [Configuration](#configuration)
- [Feature overview](#feature-overview)
  - [Tabpages](#tabpages)
  - [LSP indicators](#lsp-indicators)
  - [Conditional buffer based LSP indicators](#conditional-buffer-based-lsp-indicators)
  - [Groups](#groups)
  - [Pinning](#pinning)
  - [Regular tab sizes](#regular-tab-sizes)
  - [Numbers](#numbers)
  - [Sorting](#sorting)
  - [Sidebar offset](#sidebar-offset-1)
  - [Buffer pick functionality](#buffer-pick-functionality)
  - [Mouse actions](#mouse-actions)
  - [Custom area](#custom-area)
- [FAQ](#faq)

## Features

- Colours derived from colorscheme where possible.

- Sort buffers by `extension`, `directory` or pass in a custom compare function

- Configuration via lua functions for greater customization.

#### Alternate styling

![slanted tabs](https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png)

**NOTE**: some terminals require special characters to be padded so set the style to `padded_slant` if the appearance isn't right in your terminal emulator. Please keep in mind
though that results may vary depending on your terminal emulator of choice and this style might will not work for all terminals

see: `:h bufferline-styling`

#### Tabpages mode

<img width="800" alt="Screen Shot 2022-03-08 at 17 39 57" src="https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png">

You can use this plugin to visualise only native vim tabpages.

#### LSP error indicators

![LSP error](https://user-images.githubusercontent.com/22454918/111993085-1d299700-8b0e-11eb-96eb-c1c289e36b08.png)

#### Buffer Groups

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

#### Sidebar offset

![explorer header](https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png)

#### Buffer numbers

![bufferline with numbers](https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png)

Ordinal number and buffer number with a customized number styles.

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

#### Buffer pick

![bufferline pick](https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif)

#### Unique buffer names

![duplicate names](https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png)

#### Close icons

![close button](https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif)

#### Buffer re-ordering

![re-order buffers](https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif)

This order can be persisted between sessions (enabled by default).

#### Pinning buffers

<img width="899" alt="Screen Shot 2022-03-31 at 18 13 50" src="https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png">

## Requirements

- Neovim 0.5+
- A patched font (see [nerd fonts](https://github.com/ryanoasis/nerd-fonts))

## Installation

It is advised that you specify either the latest tag or a specific tag and bump them manually if you'd prefer to inspect changes before updating.

**Lua**

```lua
-- using packer.nvim
use {'akinsho/bufferline.nvim', tag = "*", requires = 'kyazdani42/nvim-web-devicons'}
```

**Vimscript**

```vim
Plug 'kyazdani42/nvim-web-devicons' " Recommended (for coloured icons)
" Plug 'ryanoasis/vim-devicons' Icons without colours
Plug 'akinsho/bufferline.nvim', { 'tag': '*' }
```

## What about Tabs?

This plugin, as the name implies, shows a user their buffers but can also show tabs if using the `tabs` mode. If you're unclear as to what the difference
is please read `:help tabpage`.

## Caveats

- This won't appeal to everyone's tastes. This plugin is opinionated about how the tabline
  looks, it's unlikely to please everyone.

- I want to prevent this becoming a pain to maintain so I'll be conservative about what I add.

- This plugin relies on some basic highlights being set by your colour scheme
  i.e. `Normal`, `String`, `TabLineSel` (`WildMenu` as fallback), `Comment`.
  It's unlikely to work with all colour schemes. You can either try manually overriding the colours or
  manually creating these highlight groups before loading this plugin.

- If the contrast in your colour scheme isn't very high, think an all black colour scheme, some of the highlights of
  this plugin won't really work as intended since it depends on darkening things.

## Usage

See the docs for details `:h bufferline.nvim`

You need to be using `termguicolors` for this plugin to work, as it reads the hex `gui` color values
of various highlight groups.

**Vimscript**

```vim
" In your init.lua or init.vim
set termguicolors
lua << EOF
require("bufferline").setup{}
EOF
```

**Lua**

```lua
vim.opt.termguicolors = true
require("bufferline").setup{}
```

You can close buffers by clicking the close icon or by _right clicking_ the tab anywhere

A few of this plugins commands can be mapped for ease of use.

```vim
" These commands will navigate through buffers in order regardless of which mode you are using
" e.g. if you change the order of buffers :bnext and :bprevious will not respect the custom ordering
nnoremap <silent>[b :BufferLineCycleNext<CR>
nnoremap <silent>b] :BufferLineCyclePrev<CR>

" These commands will move the current buffer backwards or forwards in the bufferline
nnoremap <silent><mymap> :BufferLineMoveNext<CR>
nnoremap <silent><mymap> :BufferLineMovePrev<CR>

" These commands will sort buffers by directory, language, or a custom criteria
nnoremap <silent>be :BufferLineSortByExtension<CR>
nnoremap <silent>bd :BufferLineSortByDirectory<CR>
nnoremap <silent><mymap> :lua require'bufferline'.sort_buffers_by(function (buf_a, buf_b) return buf_a.id < buf_b.id end)<CR>

```

If you manually arrange your buffers using `:BufferLineMove{Prev|Next}` during an nvim session this can be persisted for the session.
This is enabled by default but you need to ensure that your `sessionoptions+=globals` otherwise the session file will
not track global variables which is the mechanism used to store your sort order.

## Configuration

```lua
require('bufferline').setup {
  options = {
    mode = "buffers", -- set to "tabs" to only show tabpages instead
    numbers = "none" | "ordinal" | "buffer_id" | "both" | function({ ordinal, id, lower, raise }): string,
    close_command = "bdelete! %d",       -- can be a string | function, see "Mouse actions"
    right_mouse_command = "bdelete! %d", -- can be a string | function, see "Mouse actions"
    left_mouse_command = "buffer %d",    -- can be a string | function, see "Mouse actions"
    middle_mouse_command = nil,          -- can be a string | function, see "Mouse actions"
    -- NOTE: this plugin is designed with this icon in mind,
    -- and so changing this is NOT recommended, this is intended
    -- as an escape hatch for people who cannot bear it for whatever reason
    indicator_icon = '▎',
    buffer_close_icon = '',
    modified_icon = '●',
    close_icon = '',
    left_trunc_marker = '',
    right_trunc_marker = '',
    --- name_formatter can be used to change the buffer's label in the bufferline.
    --- Please note some names can/will break the
    --- bufferline so use this at your discretion knowing that it has
    --- some limitations that will *NOT* be fixed.
    name_formatter = function(buf)  -- buf contains a "name", "path" and "bufnr"
      -- remove extension from markdown files for example
      if buf.name:match('%.md') then
        return vim.fn.fnamemodify(buf.name, ':t:r')
      end
    end,
    max_name_length = 18,
    max_prefix_length = 15, -- prefix used when a buffer is de-duplicated
    tab_size = 18,
    diagnostics = false | "nvim_lsp" | "coc",
    diagnostics_update_in_insert = false,
    diagnostics_indicator = function(count, level, diagnostics_dict, context)
      return "("..count..")"
    end,
    -- NOTE: this will be called a lot so don't do any heavy processing here
    custom_filter = function(buf_number, buf_numbers)
      -- filter out filetypes you don't want to see
      if vim.bo[buf_number].filetype ~= "<i-dont-want-to-see-this>" then
        return true
      end
      -- filter out by buffer name
      if vim.fn.bufname(buf_number) ~= "<buffer-name-I-dont-want>" then
        return true
      end
      -- filter out based on arbitrary rules
      -- e.g. filter out vim wiki buffer from tabline in your work repo
      if vim.fn.getcwd() == "<work-repo>" and vim.bo[buf_number].filetype ~= "wiki" then
        return true
      end
      -- filter out by it's index number in list (don't show first buffer)
      if buf_numbers[1] ~= buf_number then
        return true
      end
    end,
    offsets = {{filetype = "NvimTree", text = "File Explorer" | function , text_align = "left" | "center" | "right"}},
    color_icons = true | false, -- whether or not to add the filetype icon highlights
    show_buffer_icons = true | false, -- disable filetype icons for buffers
    show_buffer_close_icons = true | false,
    show_buffer_default_icon = true | false, -- whether or not an unrecognised filetype should show a default icon
    show_close_icon = true | false,
    show_tab_indicators = true | false,
    persist_buffer_sort = true, -- whether or not custom sorted buffers should persist
    -- can also be a table containing 2 custom separators
    -- [focused and unfocused]. eg: { '|', '|' }
    separator_style = "slant" | "thick" | "thin" | { 'any', 'any' },
    enforce_regular_tabs = false | true,
    always_show_bufferline = true | false,
    sort_by = 'insert_after_current' |'insert_at_end' | 'id' | 'extension' | 'relative_directory' | 'directory' | 'tabs' | function(buffer_a, buffer_b)
      -- add custom logic
      return buffer_a.modified > buffer_b.modified
    end
  }
}

```

## Feature overview

### Tabpages

This plugin can also be set to show only tabpages. This can be done by setting the `mode` option to `tabs`. This will change the bufferline to a tabline
it has a lot of the same features/styling but not all.
A few things to note are

- Diagnostics only show if the buffer with issues is the current window selected in that tab page
- Sorting doesn't work yet as that needs to be thought through.
- Grouping doesn't work yet as that also needs to be thought through.

### LSP indicators

By setting `diagnostics = "nvim_lsp" | "coc"` you will get an indicator in the bufferline for a given tab if it has any errors
This will allow you to tell at a glance if a particular buffer has errors. Currently only the native neovim lsp is
supported, mainly because it has the easiest API for fetching all errors for all buffers (with an attached lsp client).

In order to customise the appearance of the diagnostic count you can pass a custom function in your setup.

![custom indicator](https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png)

<details>
  <summary><b>Snippet</b></summary>

```lua
-- rest of config ...

--- count is an integer representing total count of errors
--- level is a string "error" | "warning"
--- diagnostics_dict is a dictionary from error level ("error", "warning" or "info")to number of errors for each level.
--- this should return a string
--- Don't get too fancy as this function will be executed a lot
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  local icon = level:match("error") and " " or " "
  return " " .. icon .. count
end

```

</details>

![diagnostics_indicator](https://user-images.githubusercontent.com/4028913/112573484-9ee92100-8da9-11eb-9ffd-da9cb9cae3a6.png)

<details>
  <summary><b>Snippet</b></summary>

```lua

diagnostics_indicator = function(count, level, diagnostics_dict, context)
  local s = " "
  for e, n in pairs(diagnostics_dict) do
    local sym = e == "error" and " "
      or (e == "warning" and " " or "" )
    s = s .. n .. sym
  end
  return s
end
```

</details>

The highlighting for the file name if there is an error can be changed by replacing the highlights for
see `:h bufferline-highlights`.

### Conditional buffer based LSP indicators

LSP indicators can additionally be reported conditionally, based on buffer context. For instance, you could disable reporting LSP indicators for the current buffer and only have them appear for other buffers.

```lua
diagnostics_indicator = function(count, level, diagnostics_dict, context)
  if context.buffer:current() then
    return ''
  end

  return ''
end
```

![current](https://user-images.githubusercontent.com/58056722/119390133-e5d19500-bccc-11eb-915d-f5d11f8e652c.jpeg)
![visible](https://user-images.githubusercontent.com/58056722/119390136-e66a2b80-bccc-11eb-9a87-e622e3e20563.jpeg)

The first bufferline shows `diagnostic.lua` as the currently opened `current` buffer. It has LSP reported errors, but they don't show up in the bufferline.
The second bufferline shows `500-nvim-bufferline.lua` as the currently opened `current` buffer. Because the 'faulty' `diagnostic.lua` buffer has now transitioned from `current` to `visible`, the LSP indicator does show up.

### Groups

![groups](https://user-images.githubusercontent.com/22454918/132225763-1bfeb6cb-40e1-414b-8355-05726778b8b8.png)

The buffers this plugin shows can be grouped based on a users configuration. Groups are a way of allowing a user to visualize related buffers in clusters
as well as operating on them together e.g. by clicking the group indicator all grouped buffers can be hidden. They are partially inspired by
google chrome's tabs as well as centaur tab's groups.

In order to group buffers specify a list of groups in your config e.g.

```lua
groups = {
  options = {
    toggle_hidden_on_enter = true -- when you re-enter a hidden group this options re-opens that group so the buffer is visible
  },
  items = {
    {
      name = "Tests", -- Mandatory
      highlight = {gui = "underline", guisp = "blue"}, -- Optional
      priority = 2, -- determines where it will appear relative to other groups (Optional)
      icon = "", -- Optional
      matcher = function(buf) -- Mandatory
        return buf.name:match('%_test') or buf.name:match('%_spec')
      end,
    },
    {
      name = "Docs",
      highlight = {gui = "undercurl", guisp = "green"},
      auto_close = false,  -- whether or not close this group if it doesn't contain the current buffer
      matcher = function(buf)
        return buf.name:match('%.md') or buf.name:match('%.txt')
      end,
      separator = { -- Optional
        style = require('bufferline.groups').separator.tab
      },
    }
  }
}
```

#### Ordering groups

Groups are ordered by their position in the `items` list, the first group shows at the start of the bufferline and so on.
You might want to order groups _around_ the un-grouped buffers e.g. `| group 1 | buf 1 (ungrouped) | buf 2 (ungrouped) | group 2 |`.
In this case builtin groups are provided (for now just the `ungrouped`) builtin so you can achieve the order above using

```lua
local groups = require('bufferline.groups')
groups = {
  items = {
    {name = "group 1", ... },
    groups.builtin.ungrouped, -- the ungrouped buffers will be in the middle of the grouped ones
    {name = "group 2", ...},
  }
}
```

#### Group commands

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

Grouped buffers can also be interacted with using a few commands namely
These commands can be <kbd>tab</kbd> completed to open a list of the current groups.

- `:BufferLineGroupClose` <tab> - which will close all buffers in this group
- `:BufferLineGroupToggle` <tab> - which will hide or show a group

Grouped buffers can also be interacted with using the `require('bufferline').group_action` API.

e.g.

```lua
function _G.__group_open()
  require('bufferline').group_action(<GROUP_NAME>, function(buf)
    vim.cmd('vsplit '..buf.path)
  end)
end
```

### Pinning

Buffers can be pinned to the start of the bufferline by using the `:BufferLineTogglePin` command, this will override other groupings or sorting order for the buffer and position it left of all other buffers.

Pinned buffers are essentially a builtin group that positions the assigned
elements. The icons and highlights for pinned buffers can be changed similarly
to other groups e.g.

```lua
 config = {
    options = {
        groups = {
            items = {
                require('bufferline.groups').builtin.pinned:with({ icon = "" }),
                ... -- other items
            }
        }
    }
 }
```

### Regular tab sizes

Generally this plugin enforces a minimum tab size so that the buffer line
appears consistent. Where a tab is smaller than the tab size it is padded.
If it is larger than the tab size it is allowed to grow up to the max name
length specified (+ the other indicators).
If you set `enforce_regular_tabs = true` tabs will be prevented from extending beyond
the tab size and all tabs will be the same length

### Numbers

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

You can prefix buffer names with either the `ordinal` or `buffer id`, using the `numbers` option.
Currently this can be specified as either a string of `buffer_id` | `ordinal` or a function
This function allows maximum flexibility in determining the appearance of this section.
It is passed a table with the following keys:

- `raise` - a helper function to convert the passed number to superscript e.g. `raise(id)`.
- `lower` - a helper function to convert the passed number to subscript e.g. `lower(id)`.
- `ordinal` - The buffer ordinal number.
- `id` - The buffer ID.

```lua
  -- For ⁸·₂
  numbers = function(opts)
    return string.format('%s·%s', opts.raise(opts.id), opts.lower(opts.ordinal))
  end,

  -- For ₈.₂
  numbers = function(opts)
    return string.format('%s.%s', opts.lower(opts.id), opts.lower(opts.ordinal))
  end,

  -- For 2.)8.) - change he order of arguments to change the order in the string
  numbers = function(opts)
    return string.format('%s.)%s.)', opts.ordinal, opts.id)
  end,

  -- For 8|² -
  numbers = function(opts)
    return string.format('%s|%s.)', opts.id, opts.raise(opts.ordinal))
  end,
```

### Sorting

Bufferline allows you to sort the visible buffers by `extension`, `directory` or `tabs`:

**NOTE**: If using a plugin such as `vim-rooter` and you want to sort by path, prefer using `directory` rather than
`relative_directory`. Relative directory works by ordering relative paths first, however if you move from
project to project and vim switches its directory, the bufferline will re-order itself as a different set of
buffers will now be relative.

```vim
" Using vim commands
:BufferLineSortByExtension
:BufferLineSortByDirectory
:BufferLineSortByTabs
```

```lua
-- Or using lua functions
:lua require'bufferline'.sort_buffers_by('extension')
:lua require'bufferline'.sort_buffers_by('directory')
:lua require'bufferline'.sort_buffers_by('tabs')
```

For more advanced usage you can provide a custom compare function which will
receive two buffers to compare. You can see what fields are available to use using

```lua
sort_by = function(buffer_a, buffer_b)
  print(vim.inspect(buffer_a))
-- add custom logic
  local mod_a = vim.loop.fs_stat(buffer_a.path).mtime.sec
  local mod_b = vim.loop.fs_stat(buffer_b.path).mtime.sec
  return mod_a > mod_b
end
```

When using a sorted bufferline it's advisable that you use the `BufferLineCycleNext` and `BufferLineCyclePrev`
commands since these will traverse the bufferline bufferlist in order whereas `bnext` and `bprev` will cycle
buffers according to the buffer numbers given by vim.

### Closing buffers

Bufferline provides _a few_ commands to handle closing buffers visible in the tabline using `BufferLineCloseRight` and `BufferLineCloseLeft`.
As their names suggest these commands will close all visible buffers to the left or right of the current buffer.
Another way to close any single buffer is the `BufferLinePickClose` command ([see below](#buffer-pick-functionality)).

### Sidebar offset

You can prevent the bufferline drawing above a **vertical** sidebar split such as a file explorer.
To do this you must set the `offsets` configuration option to a list of tables containing the details of the window to avoid.
_NOTE:_ this is only relevant for left or right aligned sidebar windows such as `NvimTree`, `NERDTree` or `Vista`

```lua
offsets = {
  {
    filetype = "NvimTree",
    text = "File Explorer",
    highlight = "Directory",
    text_align = "left"
  }
}
```

The `filetype` is used to check whether a particular window is a match, the `text` is _optional_ and will show above the window if specified.
`text` can be either a string or a function which should also return a string. See the example below.
_NOTE:_ to find the `filetype` of a side panel go into the buffer and run `:echo &filetype` to print its `filetype`.

```lua
offsets = {
  {
    filetype = "NvimTree",
    text = function()
      return vim.fn.getcwd()
    end,
    highlight = "Directory",
    text_align = "left"
  }
}
```

If it is too long it will be truncated. The highlight controls what highlight is shown above the window.
You can also change the alignment of the text in the offset section using `text_align` which can be set to `left`, `right` or `center`.
You can also add a `padding` key which should be an integer if you want the offset to be larger than the window width.

### Buffer pick functionality

Using the `BufferLinePick` command will allow for easy selection of a buffer in view.
Trigger the command, using `:BufferLinePick` or better still map this to a key, e.g.

```vim
nnoremap <silent> gb :BufferLinePick<CR>
```

then pick a buffer by typing the character for that specific
buffer that appears

![bufferline_pick](https://user-images.githubusercontent.com/22454918/111994691-f2404280-8b0f-11eb-9bc1-6664ccb93154.gif)

Likewise, `BufferLinePickClose` closes the buffer instead of viewing it.

### `BufferLineGoToBuffer`

You can select a buffer by it's _visible_ position in the bufferline using the `BufferLineGoToBuffer`
command. This means that if you have 60 buffers open but only 7 visible in the bufferline
then using `BufferLineGoToBuffer 4` will go to the 4th visible buffer not necessarily the 5 in the
absolute list of open buffers.

```
<- (30) | buf31 | buf32 | buf33 | buf34 | buf35 | buf36 | buf37 (24) ->
```

Using `BufferLineGoToBuffer 4` will open `buf34` as it is the 4th visible buffer.

This can then be mapped using

```vim
nnoremap <silent><leader>1 <Cmd>BufferLineGoToBuffer 1<CR>
nnoremap <silent><leader>2 <Cmd>BufferLineGoToBuffer 2<CR>
nnoremap <silent><leader>3 <Cmd>BufferLineGoToBuffer 3<CR>
nnoremap <silent><leader>4 <Cmd>BufferLineGoToBuffer 4<CR>
nnoremap <silent><leader>5 <Cmd>BufferLineGoToBuffer 5<CR>
nnoremap <silent><leader>6 <Cmd>BufferLineGoToBuffer 6<CR>
nnoremap <silent><leader>7 <Cmd>BufferLineGoToBuffer 7<CR>
nnoremap <silent><leader>8 <Cmd>BufferLineGoToBuffer 8<CR>
nnoremap <silent><leader>9 <Cmd>BufferLineGoToBuffer 9<CR>
```

### Mouse actions

You can configure different type of mouse clicks to behave differently. The current mouse click types are

- Left - `left_mouse_command`
- Right - `right_mouse_command`
- Middle - `middle_mouse_command`
- Close - `close_command`

Currently left mouse opens the selected buffer but the command can be tweaked using `left_mouse_command`
which can be specified as either a lua function or string which uses [lua's printf style string formatting](https://www.lua.org/pil/20.html) e.g. `buffer %d`

You can do things like open a vertical split on right clicking the buffer name for example using

```lua
right_mouse_command = "vertical sbuffer %d"
```

Or you can set the value to a function and handle the click action however you please for example you can use
another plugin such as [bufdelete.nvim](https://github.com/famiu/bufdelete.nvim) to handle closing the buffer using the `close_command`.

```lua
left_mouse_command = function(bufnum)
   require('bufdelete').bufdelete(bufnum, true)
end
```

### Custom functions

A user can also execute arbitrary functions against a buffer using the
`exec` function. For example

```lua
    require('bufferline').exec(
        4, -- the forth visible buffer from the left
        user_function -- an arbitrary user function which gets passed the buffer
    )

    -- e.g.
    function _G.bdel(num)
        require('bufferline').exec(num, function(buf, visible_buffers)
            vim.cmd('bdelete '..buf.id)
        end
    end

    vim.cmd [[
        command -count Bdel <Cmd>lua _G.bdel(<count>)<CR>
    ]]
```

### Custom area

![custom area](https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png)

You can also add custom content at the start or end of the bufferline using `custom_areas`
this option allows a user to specify a function which should return the text and highlight for that text
to be shown in a list of tables. For example:

```lua

custom_areas = {
  right = function()
    local result = {}
    local seve = vim.diagnostic.severity
    local error = #vim.diagnostic.get(0, {severity = seve.ERROR})
    local warning = #vim.diagnostic.get(0, {severity = seve.WARN})
    local info = #vim.diagnostic.get(0, {severity = seve.INFO})
    local hint = #vim.diagnostic.get(0, {severity = seve.HINT})

    if error ~= 0 then
      table.insert(result, {text = "  " .. error, guifg = "#EC5241"})
    end

    if warning ~= 0 then
      table.insert(result, {text = "  " .. warning, guifg = "#EFB839"})
    end

    if hint ~= 0 then
      table.insert(result, {text = "  " .. hint, guifg = "#A3BA5E"})
    end

    if info ~= 0 then
      table.insert(result, {text = "  " .. info, guifg = "#7EA9A7"})
    end
    return result
  end,
}
```

Please note that this function will be called a lot and should be as inexpensive as possible so it does
not block rendering the tabline.

## FAQ

- **Why isn't the bufferline appearing?**

  The most common reason for this that has come up in various issues is it clashes with
  another plugin. Please make sure that you do not have another bufferline plugin installed.

  If you are using `airline` make sure you set `let g:airline#extensions#tabline#enabled = 0`.
  If you are using `lightline` this also takes over the tabline by default and needs to be deactivated.

- **Doesn't this plugin go against the "vim way"?**

  This is much better explained by [buftablines's author](https://github.com/ap/vim-buftabline#why-this-and-not-vim-tabs).
  Please read this for a more comprehensive answer to this questions. The short answer to this is
  buffers represent files in nvim and tabs, a collection of windows (or just one). Vim natively allows visualising tabs i.e. collections
  of window, but not just the files that are open. There are _endless_ debates on this topic, but allowing a user to see what files they
  have open doesn't go against any clearly stated vim philosophy. It's a text editor and not a religion 🙏.
  Obviously this won't appeal to everyone, which isn't really a feasible objective anyway.
