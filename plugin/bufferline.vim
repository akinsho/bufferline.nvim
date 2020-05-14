if exists('g:loaded_bufferline') | finish | endif " prevent loading file twice

" A lua based plugin isn't going to work without these
if !has('nvim')
    echohl Error
    echom "Sorry this plugin only works with versions of neovim that support lua"
    echohl clear
    finish
endif

let g:loaded_bufferline = 1
