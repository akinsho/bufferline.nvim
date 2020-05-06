" if exists('g:loaded_bufferline') | finish | endif " prevent loading file twice
" let s:save_cpo = &cpo " save user coptions
" set cpo&vim " reset them to defaults

function! TabLine()
    return luaeval("require'bufferline'.bufferline()")
endfunction

" let &cpo = s:save_cpo " and restore after
" unlet s:save_cpo

" let g:loaded_bufferline = 1
set showtabline=2
set tabline=%!TabLine()
