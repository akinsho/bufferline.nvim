" if exists('g:loaded_bufferline') | finish | endif " prevent loading file twice
" let s:save_cpo = &cpo " save user coptions
" set cpo&vim " reset them to defaults

function! TabLine() abort
    return luaeval("require'bufferline'.bufferline()")
endfunction

" let &cpo = s:save_cpo " and restore after
" unlet s:save_cpo

let g:loaded_bufferline = 1

function! BufferlineColors() abort
  let s:colors = {
        \ 'gold'         : '#F5F478',
        \ 'bright_blue'  : '#A2E8F6',
        \ 'dark_blue'    : '#4e88ff',
        \ 'dark_yellow'  : '#d19a66',
        \ 'green'        : '#98c379'
        \}
  let normal_fg = synIDattr(hlID('Normal'), 'fg#')
  let normal_bg = synIDattr(hlID('Normal'), 'bg#')
  let comment_fg = synIDattr(hlID('Comment'), 'fg#')
  silent! execute 'highlight! BufferLine guifg='.comment_fg.' guibg=#1b1e24 gui=NONE'
  silent! execute 'highlight! BufferLineBackground guifg='.s:colors['gold'].' guibg=#1b1e24 gui=bold'
  silent! execute 'highlight! BufferLineSelected guifg='.normal_fg.' guibg='.normal_bg.' gui=bold,italic'
endfunction

augroup BufferlineColors
    autocmd!
    autocmd VimEnter,ColorScheme * call BufferlineColors()
augroup END

set showtabline=2
set tabline=%!TabLine()
