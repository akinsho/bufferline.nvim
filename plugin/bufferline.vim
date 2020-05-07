if exists('g:loaded_bufferline') | finish | endif " prevent loading file twice

" A lua based plugin isn't going to work without these
if !has('nvim')
    echohl Error
    echom "Sorry this plugin only works with versions of neovim that support lua"
    echohl clear
    finish
endif

" Setup plugin internals like autocommands
" Expose this to the user so they can pass in color
" preferences in using lua syntax
" BLOCKED: by not knowing how to set tabline via lua
lua require'bufferline'.setup()

set showtabline=2
" TODO figure out how to do this directly in lua
set tabline=%!nvim_bufferline#render()

let g:loaded_bufferline = 1
