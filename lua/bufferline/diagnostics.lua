local M = {}

local function get_sev_name(i)
  if     i == 1 then return "error"
  elseif i == 2 then return "warning"
  elseif i == 3 then return "info"
  else return "other"
  end
end

local function get_err_dict(errs)
  local ds = {}
  local max = 3
  for _, err in ipairs (errs) do
    if err then
      -- calculate max severity
      local sev_num = err.severity
      local sev_level = get_sev_name(sev_num)
      if sev_num < max then max = sev_num end
      -- increment diagnostics dict
      if ds[sev_level] then
        ds[sev_level] = ds[sev_level] + 1
      else
        ds[sev_level] = 1
      end
    end
  end
  local max_severity = get_sev_name(max)
  return {level = max_severity, errors = ds}
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
    local d = get_err_dict(items)
    result[buf_num] = {
      count = #items,
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
