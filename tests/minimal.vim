set rtp+=.
set rtp+=../plenary.nvim
runtime! plugin/plenary.vim
set noswapfile
lua << EOF
_G.__TEST = true
EOF
