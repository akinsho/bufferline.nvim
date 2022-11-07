[![Run tests](https://github.com/akinsho/bufferline.nvim/actions/workflows/test.yaml/badge.svg)](https://github.com/akinsho/bufferline.nvim/actions/workflows/test.yaml)

<h1 align="center">
  bufferline.nvim
</h1>

<p align="center">A <i>snazzy</i> 💅 buffer line (with tabpage integration) for Neovim built using <b>lua</b>.</p>

![Demo GIF](https://user-images.githubusercontent.com/22454918/111992693-9c6a9b00-8b0d-11eb-8c39-19db58583061.gif)

<!--toc:start-->

- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Configuration](#configuration)
- [Features](#features)
  - [Alternate styling](#alternate-styling)
  - [Hover events](#hover-events)
  - [Underline indicator](#underline-indicator)
  - [Tabpages](#tabpages)
  - [LSP indicators](#lsp-indicators)
  - [Groups](#groups)
  - [Sidebar offsets](#sidebar-offsets)
  - [Numbers](#numbers)
  - [Picking](#picking)
  - [Pinning](#pinning)
  - [Unique names](#unique-names)
  - [Close icons](#close-icons)
  - [Re-ordering](#re-ordering)
  - [LSP indicators](#lsp-indicators)
  - [Custom areas](#custom-areas)
- [How do I see only buffers per tab?](#how-do-i-see-only-buffers-per-tab)
- [Caveats](#caveats)
- [FAQ](#faq)
<!--toc:end-->

This plugin shamelessly attempts to emulate the aesthetics of GUI text editors/Doom Emacs.
It was inspired by a screenshot of DOOM Emacs using [centaur tabs](https://github.com/ema2159/centaur-tabs).

## Requirements

- Neovim 0.8+
- A patched font (see [nerd fonts](https://github.com/ryanoasis/nerd-fonts))
- A colorscheme (either your custom highlight or a maintained one somewhere)

## Installation

It is advised that you specify either the latest tag or a specific tag and bump them manually if you'd prefer to inspect changes before updating.
If you'd like to use an older version of the plugin compatible with nvim-0.6.1 and below please change your tag to `tag = "v1.*"`

**Lua**

```lua
-- using packer.nvim
use {'akinsho/bufferline.nvim', tag = "v3.*", requires = 'nvim-tree/nvim-web-devicons'}
```

**Vimscript**

```vim
Plug 'nvim-tree/nvim-web-devicons' " Recommended (for coloured icons)
" Plug 'ryanoasis/vim-devicons' Icons without colours
Plug 'akinsho/bufferline.nvim', { 'tag': 'v3.*' }
```

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

## Configuration

for more details on how to configure this plugin in details please see `:h bufferline-configuration`

## Features

- Colours derived from colorscheme where possible.

- Sort buffers by `extension`, `directory` or pass in a custom compare function

- Configuration via lua functions for greater customization.

#### Alternate styling

![slanted tabs](https://user-images.githubusercontent.com/22454918/111992989-fec39b80-8b0d-11eb-851b-010641196a04.png)

**NOTE**: some terminals require special characters to be padded so set the style to `padded_slant` if the appearance isn't right in your terminal emulator. Please keep in mind
though that results may vary depending on your terminal emulator of choice and this style might will not work for all terminals

see: `:h bufferline-styling`

---

#### Hover events

**NOTE**: this is only available for _neovim 0.8+ (nightly) ONLY_ and is still **experimental**

![hover-event-preview](https://user-images.githubusercontent.com/22454918/189106657-163b0550-897c-42c8-a571-d899bdd69998.gif)

see `:help bufferline-hover-events` for more information on configuration

---

#### Underline indicator

<img width="1355" alt="Screen Shot 2022-08-22 at 09 14 24" src="https://user-images.githubusercontent.com/22454918/185873089-2ae20db0-f292-4d96-afe4-ef0683a60709.png">

**NOTE**: as with the above your mileage will vary based on your terminal emulator. The screenshot above was achieved using kitty nightly (as of August 2022), with increased
underline thickness and an increased underline position so it sits further from the text

---

#### Tabpages

<img width="800" alt="Screen Shot 2022-03-08 at 17 39 57" src="https://user-images.githubusercontent.com/22454918/157337891-1848da24-69d6-4970-96ee-cf65b2a25c46.png">

This plugin can also be set to show only tabpages. This can be done by setting the `mode` option to `tabs`. This will change the bufferline to a tabline
it has a lot of the same features/styling but not all.

A few things to note are

- Sorting doesn't work yet as that needs to be thought through.
- Grouping doesn't work yet as that also needs to be thought through.

---

#### LSP indicators

![LSP Indicator](https://user-images.githubusercontent.com/22454918/113215394-b1180300-9272-11eb-9632-8a9f9aae99fa.png)

By setting `diagnostics = "nvim_lsp" | "coc"` you will get an indicator in the bufferline for a given tab if it has any errors
This will allow you to tell at a glance if a particular buffer has errors.

In order to customise the appearance of the diagnostic count you can pass a custom function in your setup.

<details>
  <summary><b>snippet</b></summary>

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
  <summary><b>snippet</b></summary>

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

The highlighting for the file name if there is an error can be changed by replacing the highlights for see:

`:h bufferline-highlights`

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

---

#### Groups

![bufferline_group_toggle](https://user-images.githubusercontent.com/22454918/132410772-0a4c0b95-63bb-4281-8a4e-a652458c3f0f.gif)

The buffers this plugin shows can be grouped based on a users configuration. Groups are a way of allowing a user to visualize related buffers in clusters
as well as operating on them together e.g. by clicking the group indicator all grouped buffers can be hidden. They are partially inspired by
google chrome's tabs as well as centaur tab's groups.

see `:help bufferline-groups` for more information on how to set these up

---

#### Sidebar offsets

![explorer header](https://user-images.githubusercontent.com/22454918/117363338-5fd3e280-aeb4-11eb-99f2-5ec33dff6f31.png)

---

#### Numbers

![bufferline with numbers](https://user-images.githubusercontent.com/22454918/119562833-b5f2c200-bd9e-11eb-81d3-06876024bf30.png)

You can prefix buffer names with either the `ordinal` or `buffer id`, using the `numbers` option.
Currently this can be specified as either a string of `buffer_id` | `ordinal` or a function

![numbers](https://user-images.githubusercontent.com/22454918/130784872-936d4c55-b9dd-413b-871d-7bc66caf8f17.png)

see `:help bufferline-numbers` for more details

---

#### Unique names

![duplicate names](https://user-images.githubusercontent.com/22454918/111993343-6da0f480-8b0e-11eb-8d93-44019458d2c9.png)

---

#### Close icons

![close button](https://user-images.githubusercontent.com/22454918/111993390-7a254d00-8b0e-11eb-9951-43b4350f6a29.gif)

---

#### Re-ordering

![re-order buffers](https://user-images.githubusercontent.com/22454918/111993463-91643a80-8b0e-11eb-87f0-26acfe92c021.gif)

This order can be persisted between sessions (enabled by default).

---

#### Picking

![bufferline pick](https://user-images.githubusercontent.com/22454918/111993296-5bbf5180-8b0e-11eb-9ad9-fcf9619436fd.gif)

---

#### Pinning

<img width="899" alt="Screen Shot 2022-03-31 at 18 13 50" src="https://user-images.githubusercontent.com/22454918/161112867-ba48fdf6-42ee-4cd3-9e1a-7118c4a2738b.png">

---

#### Custom areas

![custom area](https://user-images.githubusercontent.com/22454918/118527523-4d219f00-b739-11eb-889f-60fb06fd71bc.png)

see `:help bufferline-custom-areas`

## How do I see only buffers per tab?

This behaviour is _not native in neovim_ there is no internal concept of localised buffers to tabs as
that is not how tabs were designed to work. They were designed to show an arbitrary layout of windows per tab.

You can get this behaviour using [scope.nvim](https://github.com/tiagovla/scope.nvim) with this plugin. Although I believe a better
long-term solution for users who want this functionality is to ask for real native support
for this upstream.

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

## FAQ

- **Why isn't the bufferline appearing?**

  The most common reason for this that has come up in various issues is it clashes with
  another plugin. Please make sure that you do not have another bufferline plugin installed.

  If you are using `airline` make sure you set `let g:airline#extensions#tabline#enabled = 0`.
  If you are using `lightline` this also takes over the tabline by default and needs to be deactivated.

  If you are on Windows and use the GUI version of nvim (nvim-qt.exe) then also ensure, that `GuiTabline`
  is disabled. For this create a file called `ginit.vim` in your nvim config directory and put the line
  `GuiTabline 0` in it. Otherwise the QT tabline will overlay any terminal tablines.

- **Doesn't this plugin go against the "vim way"?**

  This is much better explained by [buftablines's author](https://github.com/ap/vim-buftabline#why-this-and-not-vim-tabs).
  Please read this for a more comprehensive answer to this questions. The short answer to this is
  buffers represent files in nvim and tabs, a collection of windows (or just one). Vim natively allows visualising tabs i.e. collections
  of window, but not just the files that are open. There are _endless_ debates on this topic, but allowing a user to see what files they
  have open doesn't go against any clearly stated vim philosophy. It's a text editor and not a religion 🙏.
  Obviously this won't appeal to everyone, which isn't really a feasible objective anyway.
