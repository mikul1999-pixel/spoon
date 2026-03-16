local M = {}

-- All unified window actions. tiled + floating manager
local _spoonPath
local _bind
local _frame
local _alerts
local _backend
local _cfg
local _logger
local _modes
local _policy
local _newWindowFilter

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _frame = dofile(_spoonPath .. "utils/frame.lua")
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

local _undoFrames = {}

local function effectiveScreenFrame(screen)
  local f = screen:frame()
  local ui = _cfg and _cfg.ui and _cfg.ui.statusbar or {}
  if ui.reserveTopPadding == false then return f end

  local inset = (tonumber(ui.topInset) or 0) + (tonumber(ui.tiledTopPadding) or 0)
  if inset <= 0 then return f end

  return {
    x = f.x,
    y = f.y + inset,
    w = f.w,
    h = math.max(80, f.h - inset),
  }
end

local function saveUndo(win)
  if win then _undoFrames[win:id()] = win:frame() end
end

local function snap(win, x, y, w, h, gaps, screenFrame)
  if not win then return end
  saveUndo(win)
  local f = screenFrame
  local raw = { x = f.x + f.w * x, y = f.y + f.h * y, w = f.w * w, h = f.h * h }
  win:setFrame(_frame.applyGaps(raw, f, gaps))
end

local function isFloating(win)
  if not win then return true end
  if not _backend then return true end

  local floating = _backend:isFloating(win:id())
  if floating == nil then return true end
  return floating
end

local function trace(event, message, data)
  if _logger and _logger.trace then
    _logger:trace(event, message, data)
  end
end

local function info(event, message, data)
  if _logger and _logger.info then
    _logger:info(event, message, data)
  end
end

local function shouldAutoFloat(reason)
  if _policy and _policy.shouldAutoFloat then
    local byReason = _policy:shouldAutoFloat(reason, { component = "window" })
    if byReason then return true end
    if reason ~= "moveFailure" and reason ~= "displayMoveFailure" then
      return _policy:shouldAutoFloat("geometry", { component = "window", fallbackFrom = reason })
    end
    return false
  end

  local behavior = _cfg.behavior or {}
  if reason == "moveFailure" then return behavior.autoFloatOnMoveFailure == true end
  if reason == "displayMoveFailure" then return behavior.autoFloatOnDisplayMoveFailure == true end
  return behavior.autoFloatForGeometry == true
end

local function ensureFloating(win, reason)
  if isFloating(win) then return true end
  if not shouldAutoFloat(reason) then return false end

  local ok, err = _backend:toggleFloat(win:id())
  if not ok then
    _alerts.warn(err or "Failed to auto-float window")
    return false
  end

  hs.timer.usleep(70000)
  info("window.autoFloat", "auto-floated for geometry operation", {
    reason = reason,
    winId = win:id(),
  })
  return true
end

local function workspaceBalance()
  if not _backend then return end
  local workspace = _backend:focusedWorkspace()
  local ok, err = _backend:balanceWorkspace(workspace)
  if not ok then _alerts.warn(err or "Failed to balance workspace") end
end

local function moveTiledOrSnap(win, dir, gaps)
  -- Default H/J/K/L intent: tiled windows use backend placement; floating windows snap.
  if not win then return end

  if isFloating(win) then
    local sf = effectiveScreenFrame(win:screen())
    if dir == "left" then snap(win, 0, 0, 0.5, 1, gaps, sf) end
    if dir == "right" then snap(win, 0.5, 0, 0.5, 1, gaps, sf) end
    if dir == "up" then snap(win, 0, 0, 1, 0.5, gaps, sf) end
    if dir == "down" then snap(win, 0, 0.5, 1, 0.5, gaps, sf) end
    return
  end

  local ok, err, resolved = _backend:placeWindow(win:id(), dir)
  if not ok then
    if ensureFloating(win, "moveFailure") then
      info("window.move", "fallback to floating snap after tiled move failure", {
        direction = dir,
        error = err,
      })
      local sf = effectiveScreenFrame(win:screen())
      if dir == "left" then snap(win, 0, 0, 0.5, 1, gaps, sf) end
      if dir == "right" then snap(win, 0.5, 0, 0.5, 1, gaps, sf) end
      if dir == "up" then snap(win, 0, 0, 1, 0.5, gaps, sf) end
      if dir == "down" then snap(win, 0, 0.5, 1, 0.5, gaps, sf) end
      return
    end

    _alerts.warn(err or "Failed to move tiled window")
    trace("window.place", "tiled placement failed", { direction = dir, error = err })
    return
  end

  if resolved and resolved ~= dir then
    info("window.place", "direction fallback used", {
      requested = dir,
      resolved = resolved,
    })
  end

  if _cfg.behavior and _cfg.behavior.balanceAfterDirectionalMove then
    workspaceBalance()
  end
end

local function moveAcrossDisplay(direction)
  -- Cross monitor move: tiled via yabai, floating via Hammerspoon geometry.
  local win = hs.window.focusedWindow()
  if not win then return end

  local wasFloating = isFloating(win)
  local beforeScreen = win:screen()
  local beforeScreenFrame = beforeScreen and effectiveScreenFrame(beforeScreen) or nil
  local beforeFrame = win:frame()

  local function clamp(v, min, max)
    if v < min then return min end
    if v > max then return max end
    return v
  end

  local displayPolicy = _policy and _policy.displayMove and _policy:displayMove({
    component = "window",
    direction = direction,
    floating = wasFloating,
  }) or {}

  local useYabai = displayPolicy.preferYabai ~= false
  local allowWrap = displayPolicy.wrap ~= false
  local strictFailure = displayPolicy.failureMode ~= "smart"
  local displaySel = direction == "next" and "next" or "prev"

  local function targetScreenForFallback()
    local current = win:screen()
    if not current then return nil end

    local screens = hs.screen.allScreens()
    table.sort(screens, function(a, b)
      local af = a:fullFrame()
      local bf = b:fullFrame()
      if af.x == bf.x then return af.y < bf.y end
      return af.x < bf.x
    end)

    if #screens == 0 then return nil end
    local pos = nil
    for i, s in ipairs(screens) do
      if s:id() == current:id() then
        pos = i
        break
      end
    end
    if not pos then return nil end

    if direction == "next" then
      if not allowWrap and pos == #screens then return nil end
      return screens[(pos % #screens) + 1]
    end

    if not allowWrap and pos == 1 then return nil end
    return screens[((pos - 2 + #screens) % #screens) + 1]
  end

  local function postMoveAdjustments(meta)
    if not wasFloating and displayPolicy.tiledBehavior == "retile" then
      trace("window.displayMove", "tiled move follows retile behavior", {
        direction = direction,
      })
    end

    info("window.displayMove", "display move resolved", {
      direction = direction,
      floating = wasFloating,
      targetDisplay = meta and meta.targetDisplay,
      fallbackUsed = meta and meta.fallbackUsed == true or false,
      noOp = meta and meta.noOp == true or false,
    })
  end

  if not wasFloating and useYabai then
    local ok, err, meta = _backend:moveWindowToDisplay(win:id(), displaySel, {
      follow = displayPolicy.followDisplay == true,
      wrap = allowWrap,
    })
    if ok then
      postMoveAdjustments(meta)
      return true
    end

    if strictFailure then
      _alerts.warn(err or "Failed to move window to display")
      return false
    end

    _alerts.warn(err or "Failed to move window to display")
    return false
  end

  if not wasFloating then
    _alerts.warn("Display move backend unavailable for tiled window")
    return false
  end

  local target = targetScreenForFallback()
  if target then
    if not beforeScreenFrame then return false end
    local tf = effectiveScreenFrame(target)

    local offsetX = beforeFrame.x - beforeScreenFrame.x
    local offsetY = beforeFrame.y - beforeScreenFrame.y

    local x = tf.x + offsetX
    local y = tf.y + offsetY
    local maxX = math.max(tf.x, tf.x + tf.w - beforeFrame.w)
    local maxY = math.max(tf.y, tf.y + tf.h - beforeFrame.h)

    x = clamp(x, tf.x, maxX)
    y = clamp(y, tf.y, maxY)

    saveUndo(win)
    win:setFrame({ x = x, y = y, w = beforeFrame.w, h = beforeFrame.h })

    if displayPolicy.followDisplay == true then
      win:focus()
    end

    postMoveAdjustments({
      targetDisplay = target:id(),
      fallbackUsed = false,
    })
    return true
  end

  info("window.displayMove", "display move reached monitor edge", {
    direction = direction,
    wrap = allowWrap,
  })
  return true
end

local function applyNewWindowPolicy(win)
  if not win or not _policy then return end
  if not win:isStandard() then return end

  local app = win:application()
  local appName = app and app:name() or ""
  local rule = _policy:newWindowRule(appName)
  if not rule then return end

  if rule.mode == "float" then
    local floating = _backend:isFloating(win:id())
    if floating ~= true then
      local ok, err = _backend:toggleFloat(win:id())
      if not ok then
        trace("window.policy", "failed applying float rule", {
          app = appName,
          error = err,
        })
        return
      end
      info("window.policy", "applied float app rule", {
        app = appName,
        source = rule.source,
      })
    end
  else
    trace("window.policy", "new window kept tiled", {
      app = appName,
      source = rule.source,
      insertion = rule.insertion,
    })
  end
end

local function ensureNewWindowWatcher()
  if _newWindowFilter then return end

  _newWindowFilter = hs.window.filter.new()
  _newWindowFilter:subscribe(hs.window.filter.windowCreated, function(win)
    hs.timer.doAfter(0.12, function()
      applyNewWindowPolicy(win)
    end)
  end)
end

local function focusNextScreen()
  local win = hs.window.focusedWindow()
  if not win then return end
  local next = win:screen():next()
  for _, w in ipairs(hs.window.orderedWindows()) do
    if w:screen() == next then w:focus(); return end
  end
end

local function cycleWindowsOnScreen()
  local focused = hs.window.focusedWindow()
  if not focused then return end
  local screen = focused:screen()
  local onScreen = hs.fnutils.filter(hs.window.orderedWindows(), function(w)
    return w:screen() == screen and w:isVisible()
  end)
  if #onScreen < 2 then return end
  for i, w in ipairs(onScreen) do
    if w:id() == focused:id() then
      onScreen[(i % #onScreen) + 1]:focus()
      return
    end
  end
end

local function balanceWindows(gaps)
  local focused = hs.window.focusedWindow()
  if not focused then return end
  local screen = focused:screen()
  local f = effectiveScreenFrame(screen)
  local wins = hs.fnutils.filter(hs.window.orderedWindows(), function(w)
    return w:screen() == screen and w:isVisible() and not w:isMinimized()
  end)
  if #wins == 0 then return end

  local cols = math.ceil(math.sqrt(#wins))
  local rows = math.ceil(#wins / cols)
  local cellW = f.w / cols
  local cellH = f.h / rows

  for idx, win in ipairs(wins) do
    saveUndo(win)
    local col = (idx - 1) % cols
    local row = math.floor((idx - 1) / cols)
    local raw = {
      x = f.x + col * cellW,
      y = f.y + row * cellH,
      w = cellW,
      h = cellH,
    }
    win:setFrame(_frame.applyGaps(raw, f, gaps))
  end
end

local resizeStep = 40

local function resizeVector(dir)
  local vectors = {
    left = { dx = 0, dy = 0, dw = -resizeStep, dh = 0 },
    right = { dx = 0, dy = 0, dw = resizeStep, dh = 0 },
    up = { dx = 0, dy = 0, dw = 0, dh = -resizeStep },
    down = { dx = 0, dy = 0, dw = 0, dh = resizeStep },
  }
  return vectors[dir]
end

local function resizeDirection(dir)
  -- Resize intent: try tiled backend first, then float and apply frame resize.
  local win = hs.window.focusedWindow()
  if not win then return end

  local vector = resizeVector(dir)
  if not vector then return end

  if not isFloating(win) then
    local ok, err = _backend:resizeWindow(win:id(), dir, resizeStep)
    if ok then return end

    if ensureFloating(win, "resizeFallback") then
      info("window.resize", "fallback to floating resize", {
        direction = dir,
        error = err,
      })
    else
      _alerts.warn(err or "Failed to resize tiled window")
      return
    end
  end

  if not isFloating(win) then return end

  saveUndo(win)
  local f = win:frame()
  win:setFrame({
    x = f.x + vector.dx,
    y = f.y + vector.dy,
    w = f.w + vector.dw,
    h = f.h + vector.dh,
  })
end

local function ensureResizeMode(commands)
  if not _modes then return end

  _modes:register("resize", {
    enterMessage = "Resize mode: h/j/k/l",
    exitMessage = "Exit resize",
    onDirection = function(dir)
      commands:execute("win.resize." .. dir)
    end,
  })
end

function M:bind(cfg, commands, backend, logger, modes, policy)
  _cfg = cfg
  _backend = backend
  _logger = logger
  _modes = modes
  _policy = policy
  local gaps = cfg.gaps
  ensureResizeMode(commands)
  ensureNewWindowWatcher()

  local actions = {
    ["win.move.left"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "left", gaps) end,
    ["win.move.right"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "right", gaps) end,
    ["win.move.up"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "up", gaps) end,
    ["win.move.down"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "down", gaps) end,
    ["win.snapLeft"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "left", gaps) end,
    ["win.snapRight"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "right", gaps) end,
    ["win.snapTop"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "up", gaps) end,
    ["win.snapBottom"] = function() moveTiledOrSnap(hs.window.focusedWindow(), "down", gaps) end,
    ["win.maximize"] = function()
      local win = hs.window.focusedWindow()
      if not win then return end
      if isFloating(win) then
        snap(win, 0, 0, 1, 1, gaps, effectiveScreenFrame(win:screen()))
      else
        local ok, err = _backend:toggleFullscreen(win:id())
        if not ok then _alerts.warn(err or "Failed to toggle fullscreen") end
      end
    end,
    ["win.center"] = function()
      local win = hs.window.focusedWindow()
      if not win then return end
      if isFloating(win) or ensureFloating(win, "center") then
        snap(win, 0.1, 0.1, 0.8, 0.8, gaps, effectiveScreenFrame(win:screen()))
      else
        workspaceBalance()
      end
    end,
    ["win.balance"] = function()
      local win = hs.window.focusedWindow()
      if not win then return end
      if isFloating(win) then balanceWindows(gaps)
      else workspaceBalance() end
    end,
    ["win.undo"] = function()
      local w = hs.window.focusedWindow()
      if not w then return end
      if not isFloating(w) and not ensureFloating(w, "undo") then
        _alerts.warn("Undo is only available for floating windows")
        return
      end
      if _undoFrames[w:id()] then w:setFrame(_undoFrames[w:id()]) end
    end,
    ["win.nextMonitor"] = function()
      return moveAcrossDisplay("next")
    end,
    ["win.prevMonitor"] = function()
      return moveAcrossDisplay("prev")
    end,
    ["win.nextScreen"] = focusNextScreen,
    ["win.cycleLocal"] = cycleWindowsOnScreen,
    ["win.resize.left"] = function() resizeDirection("left") end,
    ["win.resize.right"] = function() resizeDirection("right") end,
    ["win.resize.up"] = function() resizeDirection("up") end,
    ["win.resize.down"] = function() resizeDirection("down") end,
    ["win.resizeMode"] = function()
      if _modes then _modes:enter("resize") end
    end,
  }

  for action, fn in pairs(actions) do
    commands:register(action, fn, { category = "win" })
  end

  for _, binding in ipairs(cfg.bindings) do
    if actions[binding.action] then
      _bind.bind(binding.mods or cfg.hyper, binding.key, function()
        commands:execute(binding.action)
      end)
    end
  end
end

return M
