If your nvim encountered the error below when opening multiple buffers with [bufferline.nvim](https://github.com/akinsho/bufferline.nvim), try to use this fork.
```
E5108: Error executing lua ...nvim/lazy/bufferline.nvim/lua/bufferline/diagnostics.lua:72: attempt to call field 'enabled' (a nil value)
stack traceback:
	...nvim/lazy/bufferline.nvim/lua/bufferline/diagnostics.lua:72: in function 'diagnostic_is_enabled'
	...nvim/lazy/bufferline.nvim/lua/bufferline/diagnostics.lua:84: in function <...nvim/lazy/bufferline.nvim/lua/bufferline/diagnostics.lua:80>
	...nvim/lazy/bufferline.nvim/lua/bufferline/diagnostics.lua:148: in function 'get'
	...are/nvim/lazy/bufferline.nvim/lua/bufferline/buffers.lua:63: in function 'get_components'
	...local/share/nvim/lazy/bufferline.nvim/lua/bufferline.lua:56: in function <...local/share/nvim/lazy/bufferline.nvim/lua/bufferline.lua:54>
```

## Lua
```
-- using packer.nvim
use {'sherocktong/bufferline.nvim', tag = "*", requires = 'nvim-tree/nvim-web-devicons'}

-- using lazy.nvim
{'sherocktong/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'}
```

## Vimscript
```
Plug 'nvim-tree/nvim-web-devicons' " Recommended (for coloured icons)
" Plug 'ryanoasis/vim-devicons' Icons without colours
Plug 'sherocktong/bufferline.nvim', { 'tag': '*' }
```

I will submit a PR to the extension. This fork will be deleted once the PR was merged.

