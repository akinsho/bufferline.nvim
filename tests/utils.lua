local M = {}

function M.vim_enter()
  vim.cmd("doautocmd VimEnter")
end

return M
