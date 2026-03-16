local M = {}

-- Shared WM state cache for mode, focus, intent and result, scratchpad, and health
local _state = {}

local function now()
  if hs and hs.timer and hs.timer.secondsSinceEpoch then
    return hs.timer.secondsSinceEpoch()
  end
  return os.time()
end

local function clone(tbl)
  local out = {}
  for k, v in pairs(tbl or {}) do
    if type(v) == "table" then
      out[k] = clone(v)
    else
      out[k] = v
    end
  end
  return out
end

local function freshState()
  local ts = now()
  return {
    session = {
      activeMode = "normal",
      lastIntent = nil,
      lastResult = nil,
    },
    focus = {
      windowId = nil,
      workspaceId = 1,
      displayId = nil,
      ts = ts,
      source = "init",
    },
    scratchpad = {
      origins = {},
      lastIndex = 0,
    },
    health = {
      backend = nil,
      ts = ts,
    },
  }
end

function M:reset()
  _state = freshState()
end

function M:snapshot()
  return clone(_state)
end

function M:dump()
  return hs.inspect(self:snapshot())
end

function M:setMode(mode, source)
  if type(mode) ~= "string" or mode == "" then return end
  _state.session.activeMode = mode
  _state.focus.ts = now()
  _state.focus.source = source or "state"
end

function M:mode()
  return _state.session.activeMode
end

function M:recordIntent(intent)
  intent = intent or {}
  _state.session.lastIntent = {
    action = intent.action,
    direction = intent.direction,
    target = intent.target,
    source = intent.source or "state",
    meta = intent.meta,
    ts = now(),
  }
end

function M:lastIntent()
  return clone(_state.session.lastIntent)
end

function M:recordResult(result)
  result = result or {}
  _state.session.lastResult = {
    ok = result.ok == true,
    error = result.error,
    resolvedDirection = result.resolvedDirection,
    fallbackUsed = result.fallbackUsed == true,
    source = result.source or "state",
    meta = result.meta,
    ts = now(),
  }
end

function M:lastResult()
  return clone(_state.session.lastResult)
end

function M:setFocusSnapshot(snapshot)
  if type(snapshot) ~= "table" then return end

  if snapshot.windowId ~= nil then
    _state.focus.windowId = snapshot.windowId
  end
  if snapshot.workspaceId ~= nil then
    _state.focus.workspaceId = snapshot.workspaceId
  end
  if snapshot.displayId ~= nil then
    _state.focus.displayId = snapshot.displayId
  end
  _state.focus.ts = now()
  _state.focus.source = snapshot.source or "state"
end

function M:focusSnapshot()
  return clone(_state.focus)
end

function M:setFocusedWindow(windowId, source)
  self:setFocusSnapshot({ windowId = windowId, source = source or "state" })
end

function M:setFocusedDisplay(displayId, source)
  self:setFocusSnapshot({ displayId = displayId, source = source or "state" })
end

function M:setCurrentWorkspace(workspaceId, source)
  if type(workspaceId) ~= "number" then return end
  self:setFocusSnapshot({ workspaceId = workspaceId, source = source or "state" })
end

function M:currentWorkspace()
  return _state.focus.workspaceId
end

function M:setScratchOrigin(winId, workspaceId)
  if winId and workspaceId then
    _state.scratchpad.origins[winId] = workspaceId
  end
end

function M:scratchOrigin(winId)
  return _state.scratchpad.origins[winId]
end

function M:removeScratchOrigin(winId)
  _state.scratchpad.origins[winId] = nil
end

function M:setScratchpadLastIndex(index)
  local value = tonumber(index) or 0
  if value < 0 then value = 0 end
  _state.scratchpad.lastIndex = value
end

function M:scratchpadLastIndex()
  return _state.scratchpad.lastIndex or 0
end

function M:setBackendHealth(health, source)
  _state.health.backend = clone(health)
  _state.health.ts = now()
  _state.health.source = source or "state"
end

function M:backendHealth()
  return clone(_state.health)
end

M:reset()

return M
