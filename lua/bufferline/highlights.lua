local api = vim.api
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

function M.hl(item)
  return "%#" .. item .. "#"
end

function M.hl_exists(name)
  return vim.fn.hlexists(name) > 0
end

function M.set_one(name, opts)
  if opts and vim.tbl_count(opts) > 0 then
    local cmd = "highlight! " .. name
    if opts.gui and opts.gui ~= "" then
      cmd = cmd .. " " .. "gui=" .. opts.gui
    end
    if opts.guifg and opts.guifg ~= "" then
      cmd = cmd .. " " .. "guifg=" .. opts.guifg
    end
    if opts.guibg and opts.guibg ~= "" then
      cmd = cmd .. " " .. "guibg=" .. opts.guibg
    end
    if opts.guisp and opts.guisp ~= "" then
      cmd = cmd .. " " .. "guisp=" .. opts.guisp
    end
    -- TODO using api here as it warns of an error if setting highlight fails
    local success, err = pcall(vim.cmd, cmd)
    if not success then
      api.nvim_err_writeln(
        "Failed setting "
          .. name
          .. " highlight, something isn't configured correctly"
          .. "\n"
          .. err
      )
    end
  end
end

--- Map through user colors and convert the keys to highlight names
--- by changing the strings to pascal case and using those for highlight name
--- @param user_colors table
function M.set_all(user_colors)
  for name, tbl in pairs(user_colors) do
    if not tbl or not tbl.hl_name then
      api.nvim_echo({
        {
          ("Error setting highlight group: no name for %s - %s"):format(name, vim.inspect(tbl)),
          "ErrorMsg",
        },
      }, true, {})
    else
      M.set_one(tbl.hl_name, tbl)
    end
  end
end

return M
