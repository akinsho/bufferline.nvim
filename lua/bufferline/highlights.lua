local api = vim.api
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

local function hl(item)
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
    local success, err = pcall(api.nvim_command, cmd)
    if not success then
      api.nvim_err_writeln(
        "Failed setting " ..
          name .. " highlight, something isn't configured correctly" .. "\n" .. err
      )
    end
  end
end

local function shallow_copy(tbl)
  local copy = {}
  for k, v in pairs(tbl) do
    copy[k] = v
  end
  return copy
end

--- Map through user colors and convert the keys to highlight names
--- by changing the strings to pascal case and using those for highlight name
--- @param user_colors table
function M.set_all(user_colors)
  local result = {}
  for name, tbl in pairs(user_colors) do
    -- convert 'bufferline_value' to 'BufferlineValue' -> snake to pascal
    local formatted = "BufferLine" .. name:gsub("_(.)", name.upper):gsub("^%l", string.upper)
    M.set_one(formatted, tbl)
    local copy = shallow_copy(tbl)
    copy.hl = hl(formatted)
    result[name] = copy
  end
  return result
end

return M
