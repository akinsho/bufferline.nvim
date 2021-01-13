local M = {}

local function get_max_severity(errors)
  for _, err in ipairs(errors) do
    if err and err.severity == 1 then
      return "error"
    else
      return "warning"
    end
  end
end

---@param prefs table
function M.get(prefs)
  if not prefs.diagnostics or prefs.diagnostics ~= "nvim_lsp" then
    return {}
  end
  local diagnostics = vim.lsp.diagnostic.get_all()
  local result = {}
  for buf_num, items in pairs(diagnostics) do
    result[buf_num] = {
      count = #items,
      level = get_max_severity(items)
    }
  end
  return setmetatable(result, {__index = function(_,_)
    return { count = 0, level = nil}
  end})
end

---@param context table
function M.component(context)
  local diagnostics = context.diagnostics
  if diagnostics.count < 1 then
    return context.component, context.length
  end
  local indicator = diagnostics.count .. " "
  local size = context.length + vim.fn.strwidth(indicator)
  return context.component .. indicator, size
end

return M
