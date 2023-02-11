vim.opt.rtp:append({
  ".",
  "../plenary.nvim",
  "../nvim-web-devicons",
})

vim.cmd([[runtime! plugin/plenary.vim]])
vim.o.swapfile = false
_G.__TEST = true
