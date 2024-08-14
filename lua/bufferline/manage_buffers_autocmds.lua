local lazy = require("bufferline.lazy")
local commands = lazy.require("bufferline.commands")
local augroup = vim.api.nvim_create_augroup
local buf_mngr_group = augroup("BufMngrGroup", {})

local M = {}

---@param bufnr number
function M.setup_autocmds_and_keymaps(bufnr)

    vim.api.nvim_set_option_value("filetype", "buf_mngr", {
        buf = bufnr,
    })
    vim.api.nvim_set_option_value("buftype", "acwrite", { buf = bufnr })
    vim.keymap.set("n", "q", function()
        commands.toggle_buffer_manager()
    end, { buffer = bufnr, silent = true })

    vim.keymap.set("n", "<Esc>", function()
        commands.toggle_buffer_manager()
    end, { buffer = bufnr, silent = true })

    vim.api.nvim_create_autocmd({ "BufLeave" }, {
        group = buf_mngr_group,
        buffer = bufnr,
        callback = function()
            commands.toggle_buffer_manager()
        end,
    })
end

return M
