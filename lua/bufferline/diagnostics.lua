local vim = _G.vim
local api = vim.api

local M = {}

M.coc_diagnostics = function()
  local result = {}
  local coc_exists = api.nvim_call_function("exists", {"*CocAction"})
  if not coc_exists then
    return result
  end

  local diagnostics = api.nvim_call_function("CocAction", {'diagnosticList'})
  if diagnostics == nil or diagnostics == "" then
    return result
  end

  for _,diagnostic in pairs(diagnostics) do
    local current_file = diagnostic.file
    if result[current_file] == nil then
      result[current_file] = {count = 1}
    else
      result[current_file].count = result[current_file].count + 1
    end
  end
  return result
end

M.get_diagnostic_count = function (diagnostics, path)
  return diagnostics[path] ~= nil and diagnostics[path].count or 0
end

return M
