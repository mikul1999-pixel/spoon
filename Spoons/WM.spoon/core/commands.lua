local M = {}

-- Central command registry used by features and execute actions by name
local _registry = {}

function M:reset()
  _registry = {}
end

function M:register(name, fn, meta)
  if type(name) ~= "string" or name == "" then return false end
  if type(fn) ~= "function" then return false end
  _registry[name] = {
    run = fn,
    meta = meta or {},
  }
  return true
end

function M:execute(name, args)
  local cmd = _registry[name]
  if not cmd then return false end
  cmd.run(args)
  return true
end

function M:list()
  local out = {}
  for name, entry in pairs(_registry) do
    table.insert(out, { name = name, meta = entry.meta })
  end
  table.sort(out, function(a, b) return a.name < b.name end)
  return out
end

return M
