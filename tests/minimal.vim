set rtp+=.
set rtp+=../plenary.nvim
set rtp+=../nvim-web-devicons
runtime! plugin/plenary.vim
set noswapfile
lua << EOF
_G.__TEST = true
EOF
