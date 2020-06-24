---------------------------------------------------------------------------//
-- HELPERS
---------------------------------------------------------------------------//
local M = {}
-- https://stackoverflow.com/questions/1283388/lua-merge-tables
function M.deep_merge(t1, t2)
    for k, v in pairs(t2) do
        if (type(v) == "table") and (type(t1[k] or false) == "table") then
            M.deep_merge(t1[k], t2[k])
        else
            t1[k] = v
        end
    end
    return t1
end
-- return a new array containing the concatenation of all of its
-- parameters. Scaler parameters are included in place, and array
-- parameters have their values shallow-copied to the final array.
-- Note that userdata and function values are treated as scalar.
-- https://stackoverflow.com/questions/1410862/concatenation-of-tables-in-lua
function M.array_concat(...)
    local t = {}
    for n = 1,select("#",...) do
        local arg = select(n,...)
        if type(arg) == "table" then
            for _,v in ipairs(arg) do
                t[#t+1] = v
            end
        else
            t[#t+1] = arg
        end
    end
    return t
end

function M.get_plugin_variable(var, default)
  var = "bufferline_"..var
  local user_var = vim.g[var]
  return user_var or default
end

--- @param array table
--- @return table
function M.filter_duplicates(array)
  local seen = {}
  local res = {}

  for _,v in ipairs(array) do
    if (not seen[v]) then
      res[#res+1] = v
      seen[v] = true
    end
  end
  return res
end

return M
