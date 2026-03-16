local M = {}

-- Safe canvas operations
local function sanitizeElement(el)
  if type(el) ~= "table" then return el end

  local out = {}
  for k, v in pairs(el) do
    if k == "textFont" then
      if type(v) == "string" then
        out[k] = v
      elseif v ~= nil then
        out[k] = tostring(v)
      end
    else
      out[k] = v
    end
  end
  return out
end

local function sanitizeElements(elements)
  local out = {}
  for i, el in ipairs(elements or {}) do
    out[i] = sanitizeElement(el)
  end
  return out
end

function M.append(canvas, elements, context)
  local sanitized = sanitizeElements(elements)
  local ok, err = pcall(function()
    canvas:appendElements(sanitized)
  end)
  if not ok then
    print("WM canvas append failed" .. (context and (" (" .. context .. ")") or "") .. ": " .. tostring(err))
  end
  return ok
end

function M.replace(canvas, elements, context)
  local sanitized = sanitizeElements(elements)
  local ok, err = pcall(function()
    canvas:replaceElements(sanitized)
  end)
  if not ok then
    print("WM canvas replace failed" .. (context and (" (" .. context .. ")") or "") .. ": " .. tostring(err))
  end
  return ok
end

return M
