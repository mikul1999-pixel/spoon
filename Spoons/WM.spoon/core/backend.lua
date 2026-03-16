local M = {}

-- Backend that wraps Yabai operations with fallback / assumption / self healing policy
-- Idea here is to assume user intent. eg. if user tries to focus left but no window there, maybe they meant right? So loop & log it instead of showing an error
local _impl = nil
local _cfg = {}
local _logger = nil
local _policy = nil
local _state = nil

local function log(level, event, message, data)
  if not _logger or not _logger[level] then return end
  _logger[level](_logger, event, message, data)
end

local function fallbackOrder(dir)
  local map = {
    left = { "left", "right", "up", "down" },
    right = { "right", "left", "down", "up" },
    up = { "up", "down", "left", "right" },
    down = { "down", "up", "right", "left" },
  }
  return map[dir] or { dir }
end

local function directionalPolicy(action)
  if _policy and _policy.directionMode then
    return _policy:directionMode(action, { component = "backend" })
  end

  local behavior = _cfg.behavior or {}
  local map = behavior.directionalPolicy or {}
  local mode = map[action]
  if mode == "strict" or mode == "smart" then return mode end

  if behavior.directionalFallback ~= nil then
    if behavior.directionalFallback then return "smart" end
    return "strict"
  end

  return "smart"
end

local function runDirectional(action, eventName, dir, fn)
  -- Try direction first, then configured fallback directions
  local mode = directionalPolicy(action)
  local useFallback = mode ~= "strict"
  local order = useFallback and fallbackOrder(dir) or { dir }
  local firstErr = nil

  for index, candidate in ipairs(order) do
    local ok, err = fn(candidate)
    if ok then
      if index > 1 then
        log("info", eventName, "used fallback direction", {
          requested = dir,
          resolved = candidate,
          policy = mode,
        })
      end
      return true, nil, candidate
    end
    if firstErr == nil then firstErr = err end
    log("debug", eventName, "direction attempt failed", {
      requested = dir,
      attempted = candidate,
      error = err,
      policy = mode,
    })
  end

  return false, firstErr or "direction operation failed", dir
end

function M:init(ctx)
  if type(ctx) == "string" then
    return true
  end

  if type(ctx) ~= "table" then
    return false
  end

  local spoonPath = ctx.spoonPath
  local config = ctx.config or {}
  _cfg = config
  _logger = ctx.logger
  _policy = ctx.policy
  _state = ctx.state
  local name = config.workspaces and config.workspaces.backend or "yabai"

  if name ~= "yabai" then
    hs.alert.show("Unsupported backend: " .. tostring(name))
    return false
  end

  _impl = dofile(spoonPath .. "backends/yabai.lua")
  if _impl.init then _impl:init(ctx) end
  log("info", "backend.init", "backend initialized", { name = name })
  return true
end

function M:name()
  return _impl and _impl:name() or nil
end

function M:focusWorkspace(workspaceId, opts)
  if not _impl then return false, "backend unavailable" end
  return _impl:focusWorkspace(workspaceId, opts or {})
end

function M:focusedWorkspace()
  if not _impl then return nil end
  return _impl:focusedWorkspace()
end

function M:sendWindowToWorkspace(winId, workspaceId, opts)
  if not _impl then return false, "backend unavailable" end
  return _impl:sendWindowToWorkspace(winId, workspaceId, opts or {})
end

function M:windowWorkspace(winId)
  if not _impl then return nil end
  return _impl:windowWorkspace(winId)
end

function M:isFloating(winId)
  if not _impl or not _impl.isFloating then return nil end
  return _impl:isFloating(winId)
end

function M:focusDirection(dir)
  if not _impl then return false, "backend unavailable" end
  return runDirectional("focus", "focus.direction", dir, function(candidate)
    return _impl:focusDirection(candidate)
  end)
end

function M:swapDirection(dir)
  if not _impl then return false, "backend unavailable" end
  return runDirectional("swap", "swap.direction", dir, function(candidate)
    return _impl:swapDirection(candidate)
  end)
end

function M:moveWindowDirection(winId, dir)
  if not _impl or not _impl.moveWindowDirection then return false, "backend unavailable" end
  local ok, err, resolved = runDirectional("move", "move.direction", dir, function(candidate)
    return _impl:moveWindowDirection(winId, candidate)
  end)

  if ok then return true, nil, resolved end

  local shouldFloat = (_policy and _policy.shouldAutoFloat and _policy:shouldAutoFloat("moveFailure", {
    component = "backend",
    action = "move",
  }))
    or (_cfg.behavior and _cfg.behavior.autoFloatOnMoveFailure)
  if shouldFloat then
    local toggled = self:toggleFloat(winId)
    if toggled then
      log("info", "move.direction", "auto-floated window after move failure", { winId = winId })
      return false, err or "window auto-floated after failed tiled move", resolved
    end
  end
  return false, err, resolved
end

function M:placeWindow(winId, dir)
  -- High level placement intent used by H/J/K/L bindings
  if not _impl or not _impl.placeWindow then
    return self:moveWindowDirection(winId, dir)
  end

  local ok, err, resolved = runDirectional("move", "place.direction", dir, function(candidate)
    return _impl:placeWindow(winId, candidate)
  end)

  if ok then return true, nil, resolved end
  return false, err, resolved
end

function M:resizeWindow(winId, dir, step)
  if not _impl or not _impl.resizeWindow then return false, "backend unavailable" end
  return _impl:resizeWindow(winId, dir, step)
end

function M:moveWindowToDisplay(winId, displaySel, opts)
  if not _impl or not _impl.moveWindowToDisplay then return false, "backend unavailable" end
  return _impl:moveWindowToDisplay(winId, displaySel, opts or {})
end

function M:listSpaces()
  if not _impl or not _impl.listSpaces then return nil, "backend unavailable" end
  return _impl:listSpaces()
end

function M:toggleFloat(winId)
  if not _impl then return false, "backend unavailable" end
  return _impl:toggleFloat(winId)
end

function M:toggleFullscreen(winId)
  if not _impl then return false, "backend unavailable" end
  return _impl:toggleFullscreen(winId)
end

function M:balanceWorkspace(workspaceId)
  if not _impl then return false, "backend unavailable" end
  return _impl:balanceWorkspace(workspaceId)
end

function M:health()
  if not _impl or not _impl.health then
    local failed = { ok = false, backend = nil, error = "backend unavailable" }
    if _state and _state.setBackendHealth then
      _state:setBackendHealth(failed, "backend.wrapper.health")
    end
    return failed
  end
  local health = _impl:health()
  if _state and _state.setBackendHealth then
    _state:setBackendHealth(health, "backend.wrapper.health")
  end
  return health
end

return M
