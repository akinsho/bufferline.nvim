" Thin VimL wrapper around a lua function call because I can't figure out
" how not to have to do this. The clickable tabline label looks like:
"
" %@ArbitraryFunction@My_File.js
" Not sure how to pass a lua function to that instead of a viml one.
function! nvim_bufferline#handle_click(minwid, clicks, btn, modifiers) abort
  " To pass an argument to a required lua function we need to use
  " eval and pass it the arg. At least as far as I know.
  call luaeval("require'bufferline'.handle_click(_A[1], _A[2])", [a:minwid, a:btn])
endfunction

function! nvim_bufferline#handle_close_buffer(minwid, clicks, btn, modifiers) abort
  call luaeval("require'bufferline'.handle_close(_A)", a:minwid)
endfunction


function! nvim_bufferline#handle_group_click(minwid, clicks, btn, modifiers) abort
  call luaeval(
        \ "require'bufferline'.handle_group_click(_A[1], _A[2], _A[3], _A[4])",
        \ [a:minwid, a:clicks, a:btn, a:modifiers]
        \)
endfunction
