local M = {}

-- Central policy resolver for directional behavior, fallbacks, and app rules
local _policy = {}
local _sources = {
  directional = {},
  autoFloat = {},
  displayMove = {},
  newWindow = {},
}
local _logger = nil

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

local function merge(base, override)
  local out = clone(base)
  for k, v in pairs(override or {}) do
    if type(v) == "table" and type(out[k]) == "table" then
      out[k] = merge(out[k], v)
    else
      out[k] = v
    end
  end
  return out
end

local function defaults()
  return {
    directional = {
      move = "smart",
      focus = "smart",
      swap = "smart",
    },
    autoFloat = {
      geometry = true,
      moveFailure = false,
      displayMoveFailure = false,
      swapFailure = false,
    },
    displayMove = {
      preferYabai = true,
      followDisplay = true,
      wrap = true,
      failureMode = "strict",
      tiledBehavior = "retile",
      floatingBehavior = "preserve_frame",
    },
    newWindow = {
      mode = "tile",
      insertion = "stack_end",
      focus = true,
    },
    appRules = {},
  }
end

local function normalizeMode(mode)
  if mode == "strict" or mode == "smart" then return mode end
  return nil
end

local function normalizeDisplayFailureMode(mode)
  if mode == "strict" or mode == "smart" then return mode end
  return "strict"
end

local function normalizeFloatingBehavior(mode)
  if mode == "preserve_relative_frame" or mode == "preserve_frame" then
    return mode
  end
  return "preserve_frame"
end

local function normalizeTiledBehavior(mode)
  if mode == "retile" then return mode end
  return "retile"
end

local function emit(level, event, message, data)
  if not _logger or not _logger[level] then return end
  _logger[level](_logger, event, message, data)
end

local function sourceFrom(customValue, legacyValue)
  if customValue ~= nil then return "custom" end
  if legacyValue ~= nil then return "legacy" end
  return "default"
end

function M:configure(cfg, logger)
  _logger = logger

  local behavior = (cfg and cfg.behavior) or {}
  local custom = (cfg and cfg.policy) or {}
  local customDefaults = custom.defaults or {}

  local legacy = {
    directional = {
      move = normalizeMode(behavior.directionalPolicy and behavior.directionalPolicy.move),
      focus = normalizeMode(behavior.directionalPolicy and behavior.directionalPolicy.focus),
      swap = normalizeMode(behavior.directionalPolicy and behavior.directionalPolicy.swap),
    },
    autoFloat = {
      geometry = behavior.autoFloatForGeometry,
      moveFailure = behavior.autoFloatOnMoveFailure,
      displayMoveFailure = behavior.autoFloatOnDisplayMoveFailure,
      swapFailure = behavior.autoFloatOnMoveFailure,
    },
    displayMove = {
      preferYabai = behavior.preferYabaiDisplayMove,
      followDisplay = behavior.followDisplayOnMove,
    },
  }

  _policy = merge(defaults(), legacy)
  _policy = merge(_policy, customDefaults)
  if custom.appRules ~= nil then
    _policy.appRules = custom.appRules
  end

  _sources = {
    directional = {
      move = sourceFrom(customDefaults.directional and customDefaults.directional.move, legacy.directional.move),
      focus = sourceFrom(customDefaults.directional and customDefaults.directional.focus, legacy.directional.focus),
      swap = sourceFrom(customDefaults.directional and customDefaults.directional.swap, legacy.directional.swap),
    },
    autoFloat = {
      geometry = sourceFrom(customDefaults.autoFloat and customDefaults.autoFloat.geometry, legacy.autoFloat.geometry),
      moveFailure = sourceFrom(customDefaults.autoFloat and customDefaults.autoFloat.moveFailure, legacy.autoFloat.moveFailure),
      displayMoveFailure = sourceFrom(customDefaults.autoFloat and customDefaults.autoFloat.displayMoveFailure, legacy.autoFloat.displayMoveFailure),
      swapFailure = sourceFrom(customDefaults.autoFloat and customDefaults.autoFloat.swapFailure, legacy.autoFloat.swapFailure),
    },
    displayMove = {
      preferYabai = sourceFrom(customDefaults.displayMove and customDefaults.displayMove.preferYabai, legacy.displayMove.preferYabai),
      followDisplay = sourceFrom(customDefaults.displayMove and customDefaults.displayMove.followDisplay, legacy.displayMove.followDisplay),
      wrap = sourceFrom(customDefaults.displayMove and customDefaults.displayMove.wrap, nil),
      failureMode = sourceFrom(customDefaults.displayMove and customDefaults.displayMove.failureMode, nil),
      tiledBehavior = sourceFrom(customDefaults.displayMove and customDefaults.displayMove.tiledBehavior, nil),
      floatingBehavior = sourceFrom(customDefaults.displayMove and customDefaults.displayMove.floatingBehavior, nil),
    },
    newWindow = {
      mode = sourceFrom(customDefaults.newWindow and customDefaults.newWindow.mode, nil),
      insertion = sourceFrom(customDefaults.newWindow and customDefaults.newWindow.insertion, nil),
      focus = sourceFrom(customDefaults.newWindow and customDefaults.newWindow.focus, nil),
    },
  }

  if not normalizeMode(_policy.directional.move) then
    _policy.directional.move = (behavior.directionalFallback == false) and "strict" or "smart"
    _sources.directional.move = "legacyFallback"
  end
  if not normalizeMode(_policy.directional.focus) then
    _policy.directional.focus = (behavior.directionalFallback == false) and "strict" or "smart"
    _sources.directional.focus = "legacyFallback"
  end
  if not normalizeMode(_policy.directional.swap) then
    _policy.directional.swap = (behavior.directionalFallback == false) and "strict" or "smart"
    _sources.directional.swap = "legacyFallback"
  end

  if _policy.newWindow.mode ~= "float" then
    _policy.newWindow.mode = "tile"
  end
  if _policy.newWindow.insertion ~= "stack_end" and _policy.newWindow.insertion ~= "stack_start" then
    _policy.newWindow.insertion = "stack_end"
  end
  if _policy.newWindow.focus == nil then
    _policy.newWindow.focus = true
  end

  _policy.displayMove.failureMode = normalizeDisplayFailureMode(_policy.displayMove.failureMode)
  _policy.displayMove.tiledBehavior = normalizeTiledBehavior(_policy.displayMove.tiledBehavior)
  _policy.displayMove.floatingBehavior = normalizeFloatingBehavior(_policy.displayMove.floatingBehavior)
  if _policy.displayMove.wrap == nil then _policy.displayMove.wrap = true end

  if type(_policy.appRules) ~= "table" then
    _policy.appRules = {}
  end

  emit("info", "policy.configure", "policy configured", {
    directional = _policy.directional,
    appRuleCount = #_policy.appRules,
    newWindow = _policy.newWindow,
  })
end

function M:directionMode(action, context)
  local mode = _policy.directional and _policy.directional[action] or nil
  if not normalizeMode(mode) then mode = "smart" end

  emit("trace", "policy.direction", "resolved directional mode", {
    action = action,
    mode = mode,
    source = _sources.directional and _sources.directional[action] or "default",
    context = context,
  })
  return mode
end

function M:displayMove(context)
  local value = clone(_policy.displayMove or {})
  emit("trace", "policy.displayMove", "resolved display move policy", {
    preferYabai = value.preferYabai,
    followDisplay = value.followDisplay,
    wrap = value.wrap,
    failureMode = value.failureMode,
    tiledBehavior = value.tiledBehavior,
    floatingBehavior = value.floatingBehavior,
    source = _sources.displayMove,
    context = context,
  })
  return value
end

function M:shouldAutoFloat(reason, context)
  local enabled = _policy.autoFloat and _policy.autoFloat[reason] == true
  emit("trace", "policy.autoFloat", "resolved auto-float policy", {
    reason = reason,
    enabled = enabled,
    source = _sources.autoFloat and _sources.autoFloat[reason] or "default",
    context = context,
  })
  return enabled
end

function M:newWindowDefaults()
  return clone(_policy.newWindow or {})
end

function M:newWindowRule(appName)
  local defaults = self:newWindowDefaults()
  if type(appName) ~= "string" or appName == "" then
    defaults.source = "default"
    emit("trace", "policy.newWindow", "resolved new window policy", {
      app = appName,
      mode = defaults.mode,
      insertion = defaults.insertion,
      source = defaults.source,
    })
    return defaults
  end

  for _, rule in ipairs(_policy.appRules or {}) do
    if type(rule) == "table" and rule.app == appName then
      local merged = merge(defaults, rule)
      merged.source = "appRule"
      emit("info", "policy.newWindow", "applied app override", {
        app = appName,
        mode = merged.mode,
        insertion = merged.insertion,
        focus = merged.focus,
      })
      return merged
    end
  end

  defaults.source = "default"
  emit("trace", "policy.newWindow", "resolved new window policy", {
    app = appName,
    mode = defaults.mode,
    insertion = defaults.insertion,
    source = defaults.source,
  })
  return defaults
end

return M
