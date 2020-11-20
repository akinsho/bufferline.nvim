local api = vim.api
---------------------------------------------------------------------------//
-- Highlights
---------------------------------------------------------------------------//
local M = {}

local prefix = "bufferline_"

local function hl(item)
  return "%#" .. item .. "#"
end

function M.set_one(name, hl)
  if hl and vim.tbl_count(hl) > 0 then
    local cmd = "highlight! " .. name
    if hl.gui and hl.gui ~= "" then
      cmd = cmd .. " " .. "gui=" .. hl.gui
    end
    if hl.guifg and hl.guifg ~= "" then
      cmd = cmd .. " " .. "guifg=" .. hl.guifg
    end
    if hl.guibg and hl.guibg ~= "" then
      cmd = cmd .. " " .. "guibg=" .. hl.guibg
    end
    -- TODO using api here as it warns of an error if setting highlight fails
    local success, err = pcall(api.nvim_command, cmd)
    if not success then
      api.nvim_err_writeln(
        "Failed setting " ..
          name ..
            " highlight, something isn't configured correctly" .. "\n" .. err
      )
    end
  end
end

--- TODO map through user colors and convert the keys to highlight names
--- by changing the strings to pascal case and using those for highlight name
--- @param user_colors table
function M.set_all(user_colors)
  for name, tbl in pairs(user_colors) do
    name = name:gsub("_(.)", name.upper):gsub("^%l", string.upper)
    M.set_one(name, tbl)
    tbl.hlgroup = hl(name)
  end
  setmetatable(
    user_colors,
    {
      __index = function(table, key)
        local value = table[prefix .. key]
        if value then
          return value
        end
        return nil
      end
    }
  )
  -- print("user_colors:" .. vim.inspect(user_colors))
  return user_colors
end

return M
