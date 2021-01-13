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

local mt = {
  __index = function(_, _)
    return {count = 0, level = nil}
  end
}

local function is_disabled(diagnostics)
  return not diagnostics or diagnostics ~= "nvim_lsp" or not vim.lsp.diagnostic.get_all
end

---@param opts table
function M.get(opts)
  if is_disabled(opts.diagnostics) then
    return setmetatable({}, mt)
  end
  local diagnostics = vim.lsp.diagnostic.get_all()
  local result = {}
  for buf_num, items in pairs(diagnostics) do
    result[buf_num] = {
      count = #items,
      level = get_max_severity(items)
    }
  end
  return setmetatable(result, mt)
end

---@param context table
function M.component(context)
  if is_disabled(context.preferences.options) then
    return context.component, context.length
  end
  local highlight = context.current_highlights.error
  local diagnostics = context.diagnostics
  if diagnostics.count < 1 then
    return context.component, context.length
  end
  local indicator = diagnostics.count .. " "
  local size = context.length + vim.fn.strwidth(indicator)
  return context.component .. highlight .. indicator, size
end

return M
