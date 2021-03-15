local M = {}

-- return the most severe level of diagnostic
-- local function get_max_severity(errors)
--   for _, err in ipairs(errors) do
--     if err and err.severity == 1 then
--       return "error"
--     end
--   end
--   return "warning"
-- end
--
local function getErrDict (errs)
  local ds = {}
  local max = "info"
  for _, err in ipairs (errs) do
    if err then
      local s = err.severity
      if ds[s]
        then ds[s] = ds[s] + 1
        else ds[s] = 1
      end
      max = s==1 and "error" or (s==2 and "warning" or "info")
    end
  end
  return {level = max, errors = ds}
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
    local d = getErrDict(items)
    result[buf_num] = { count = #items,
                        level = d.level,
                        errors = d.errors
                      }
  end
  return setmetatable(result, mt)
end

---@param context table
function M.component(context)
  local opts = context.preferences.options
  if is_disabled(opts.diagnostics) then
    return context.component, context.length
  end
  local user_indicator = opts.diagnostics_indicator
  local highlights = context.current_highlights
  local diagnostics = context.buffer.diagnostics
  if diagnostics.count < 1 then
    return context.component, context.length
  end
  local indicator = " (" .. diagnostics.count .. ")"
  if user_indicator and type(user_indicator) == "function" then
    indicator = user_indicator(diagnostics.count, diagnostics.level, diagnostics.errors)
  end
  local highlight = highlights[diagnostics.level] or ""
  local size = context.length + vim.fn.strwidth(indicator)
  return highlight .. context.component .. indicator .. highlights.background, size
end

return M
