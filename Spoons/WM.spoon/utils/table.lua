local M = {}

function M.merge(defaults, overrides)
  local out = {}
  for k, v in pairs(defaults or {}) do out[k] = v end
  for k, v in pairs(overrides or {}) do out[k] = v end
  return out
end

return M
