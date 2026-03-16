local M = {}

-- Central command registry used by features and execute actions by name
local _registry = {}
local _state = nil

function M:reset()
  _registry = {}
end

function M:setState(state)
  _state = state
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
  if not cmd then
    if _state and _state.recordResult then
      _state:recordResult({
        ok = false,
        error = "command not found",
        source = "commands",
        meta = { action = name },
      })
    end
    return false
  end

  if _state and _state.recordIntent then
    _state:recordIntent({
      action = name,
      direction = args and args.direction,
      target = args and args.target,
      source = "commands",
      meta = cmd.meta,
    })
  end

  local ok, result = pcall(cmd.run, args)
  if not ok then
    if _state and _state.recordResult then
      _state:recordResult({
        ok = false,
        error = tostring(result),
        source = "commands",
        meta = { action = name },
      })
    end
    return false
  end

  local runOk = true
  local err = nil
  local resolvedDirection = nil
  local fallbackUsed = false
  if type(result) == "boolean" then
    runOk = result
  elseif type(result) == "table" then
    if result.ok ~= nil then runOk = result.ok == true end
    err = result.error
    resolvedDirection = result.resolvedDirection
    fallbackUsed = result.fallbackUsed == true
  end

  if _state and _state.recordResult then
    _state:recordResult({
      ok = runOk,
      error = err,
      resolvedDirection = resolvedDirection,
      fallbackUsed = fallbackUsed,
      source = "commands",
      meta = { action = name, category = cmd.meta and cmd.meta.category },
    })
  end

  if _state and _state.setFocusSnapshot then
    local focused = hs.window.focusedWindow()
    if focused then
      local screen = focused:screen()
      _state:setFocusSnapshot({
        windowId = focused:id(),
        displayId = screen and screen:id() or nil,
        source = "commands.execute",
      })
    end
  end

  return runOk
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
