local M = {}

-- Preset layouts: deterministic floating snap layout orchestration.
local _spoonPath
local _bind
local _frame
local _alerts
local _backend
local _logger
local _recentWindowByApp = {}
local _focusWatcher

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _frame = dofile(_spoonPath .. "utils/frame.lua")
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

local function log(level, event, message, data)
  if _logger and _logger[level] then
    _logger[level](_logger, event, message, data)
  end
end

local function runtimeOptions(cfg)
  local rt = cfg.layoutRuntime or {}
  return {
    reuseExisting = rt.reuseExisting ~= false,
    launchIfMissing = rt.launchIfMissing ~= false,
    createNewWhenRunning = rt.createNewWhenRunning == true,
    settleMs = tonumber(rt.settleMs) or 90,
  }
end

local function waitProfiles(cfg)
  local defaults = {
    default = { retries = 26, intervalMs = 120 },
    editor = { retries = 44, intervalMs = 150 },
  }
  local custom = (cfg.layoutRuntime and cfg.layoutRuntime.waitProfiles) or {}
  for name, profile in pairs(custom) do
    defaults[name] = {
      retries = tonumber(profile.retries) or defaults.default.retries,
      intervalMs = tonumber(profile.intervalMs) or defaults.default.intervalMs,
    }
  end
  return defaults
end

local function ensureFocusWatcher()
  if _focusWatcher then return end
  _focusWatcher = hs.window.filter.new()
  _focusWatcher:subscribe(hs.window.filter.windowFocused, function(win)
    if not win or not win.application then return end
    local app = win:application()
    if not app or not app:name() then return end
    _recentWindowByApp[app:name()] = win:id()
  end)
end

local function sortedSlots(layout)
  local out = {}
  for _, slot in ipairs(layout or {}) do table.insert(out, slot) end
  table.sort(out, function(a, b)
    return tonumber(a.order or 9999) < tonumber(b.order or 9999)
  end)
  return out
end

local function sortedScreens()
  local screens = hs.screen.allScreens()
  table.sort(screens, function(a, b)
    local af = a:fullFrame()
    local bf = b:fullFrame()
    if af.x == bf.x then return af.y < bf.y end
    return af.x < bf.x
  end)
  return screens
end

local function effectiveScreenFrame(cfg, screen)
  local f = screen:frame()
  local ui = cfg and cfg.ui and cfg.ui.statusbar or {}
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

local function resolveDisplayIndex(slotDisplay)
  local idx = tonumber(slotDisplay)
  if not idx or idx < 1 then return 1 end
  return idx
end

local function isUsableWindow(win)
  if not win then return false end
  if win:isMinimized() then return false end
  if win:isVisible() == false then return false end
  if win.isStandard and not win:isStandard() then return false end
  return true
end

local function chooseWindow(app)
  if not app then return nil, "missing app" end
  local appName = app:name()

  local main = app:mainWindow()
  if isUsableWindow(main) then return main, "main" end

  local recentId = _recentWindowByApp[appName]
  if recentId then
    local recent = hs.window.get(recentId)
    if recent and recent:application() and recent:application():name() == appName and isUsableWindow(recent) then
      return recent, "recent"
    end
  end

  local focused = hs.window.focusedWindow()
  if focused and focused:application() and focused:application():name() == appName and isUsableWindow(focused) then
    return focused, "focused"
  end

  for _, w in ipairs(app:allWindows() or {}) do
    if isUsableWindow(w) then return w, "first" end
  end

  return nil, "none"
end

local function waitForAppWindow(appName, profile, cfg)
  local opts = runtimeOptions(cfg)
  local app = hs.application.get(appName)

  if app and opts.reuseExisting then
    local win, source = chooseWindow(app)
    if win then return win, "reused:" .. source end
  end

  if app and not opts.createNewWhenRunning then
    for _ = 1, profile.retries do
      local win, source = chooseWindow(app)
      if win then return win, "reused:" .. source end
      hs.timer.usleep(profile.intervalMs * 1000)
    end
    return nil, "no-usable-window"
  end

  if not opts.launchIfMissing then
    return nil, "launch-disabled"
  end

  hs.application.launchOrFocus(appName)
  for _ = 1, profile.retries do
    app = hs.application.get(appName)
    local win, source = chooseWindow(app)
    if win then return win, "launched:" .. source end
    hs.timer.usleep(profile.intervalMs * 1000)
  end

  return nil, "launch-timeout"
end

local function resolveSpaceIndex(localIndex, displayIndex)
  local targetLocal = tonumber(localIndex)
  if not targetLocal then return nil end

  local spaces, err = _backend:listSpaces()
  if not spaces then
    log("debug", "layout.space", "failed querying spaces", { error = err })
    return targetLocal
  end

  local onDisplay = {}
  for _, s in ipairs(spaces) do
    if tonumber(s.display) == tonumber(displayIndex) then
      table.insert(onDisplay, s)
    end
  end
  table.sort(onDisplay, function(a, b)
    return tonumber(a.index or 0) < tonumber(b.index or 0)
  end)

  if #onDisplay == 0 then return targetLocal end
  if targetLocal > #onDisplay then targetLocal = #onDisplay end
  if targetLocal < 1 then targetLocal = 1 end
  return tonumber(onDisplay[targetLocal].index)
end

local function ensureFloating(winId)
  local floating = _backend:isFloating(winId)
  if floating == false then
    local ok, err = _backend:toggleFloat(winId)
    if not ok then return false, err or "failed to float window" end
    hs.timer.usleep(70000)
  end
  return true
end

local function fallbackFrameFromSlot(slot)
  if slot.fallback and slot.fallback.x then return slot.fallback end
  if slot.x ~= nil then return { x = slot.x, y = slot.y, w = slot.w, h = slot.h } end
  if slot.anchor == "left" then return { x = 0, y = 0, w = 0.5, h = 1 } end
  if slot.anchor == "right" then return { x = 0.5, y = 0, w = 0.5, h = 1 } end
  if slot.anchor == "up" then return { x = 0.5, y = 0, w = 0.5, h = 0.5 } end
  if slot.anchor == "down" then return { x = 0.5, y = 0.5, w = 0.5, h = 0.5 } end
  return { x = 0.05, y = 0.05, w = 0.9, h = 0.9 }
end

local function applyFloatSlot(entry, cfg)
  local slot = entry.slot
  local win = entry.win
  local screens = sortedScreens()
  local targetScreen = screens[resolveDisplayIndex(slot.display or slot.screen)] or screens[1]
  if not targetScreen then return false, "missing target screen" end

  local winId = entry.winId
  local displayIndex = resolveDisplayIndex(slot.display or slot.screen)

  local moved, moveErr = _backend:moveWindowToDisplay(winId, displayIndex, { follow = false, wrap = false })
  if not moved and moveErr ~= "window display did not change" then
    return false, moveErr or "failed moving to display"
  end

  if slot.space then
    local finalSpace = resolveSpaceIndex(slot.space, displayIndex)
    if finalSpace then
      local current = _backend:windowWorkspace(winId)
      if tonumber(current) ~= tonumber(finalSpace) then
        local sent, sendErr = _backend:sendWindowToWorkspace(winId, finalSpace, { sendFollow = false })
        if not sent then return false, sendErr or "failed sending to workspace" end
      end
    end
  end

  local floated, floatErr = ensureFloating(winId)
  if not floated then return false, floatErr end

  win:moveToScreen(targetScreen)
  local frameSpec = fallbackFrameFromSlot(slot)
  local sf = effectiveScreenFrame(cfg, targetScreen)
  local raw = {
    x = sf.x + sf.w * frameSpec.x,
    y = sf.y + sf.h * frameSpec.y,
    w = sf.w * frameSpec.w,
    h = sf.h * frameSpec.h,
  }
  win:setFrame(_frame.applyGaps(raw, sf, cfg.gaps))
  return true
end

local function resolveEntries(layout, cfg)
  local entries = {}
  local profileMap = waitProfiles(cfg)

  for _, slot in ipairs(sortedSlots(layout)) do
    local appName = cfg.apps[slot.app] or slot.app
    local profileName = slot.waitProfile or (slot.app == "editor" and "editor") or "default"
    local profile = profileMap[profileName] or profileMap.default

    local win, selection = waitForAppWindow(appName, profile, cfg)
    if win then
      table.insert(entries, {
        appName = appName,
        slot = slot,
        win = win,
        winId = win:id(),
      })
      log("debug", "layout.resolve", "resolved window", {
        app = appName,
        selection = selection,
        windowId = win:id(),
      })
    else
      return nil, "window unavailable for " .. tostring(appName) .. " (" .. tostring(selection) .. ")"
    end
  end

  return entries
end

local function runLayout(name, layout, cfg)
  local opts = runtimeOptions(cfg)
  local entries, resolveErr = resolveEntries(layout, cfg)
  if not entries then
    _alerts.warn("Layout " .. name .. " failed: " .. tostring(resolveErr))
    return false
  end

  local failures = 0
  for _, entry in ipairs(entries) do
    local ok, err = applyFloatSlot(entry, cfg)
    if not ok then
      failures = failures + 1
      log("warn", "layout.float", "slot apply failed", {
        layout = name,
        app = entry.appName,
        error = err,
      })
    end
    hs.timer.usleep(opts.settleMs * 1000)
  end

  if failures > 0 then
    _alerts.warn(string.format("Layout %s: %d/%d applied", name, #entries - failures, #entries))
    return false
  end

  _alerts.show("Layout " .. name .. " applied (floating)")
  log("info", "layout.run", "layout apply finished", {
    layout = name,
    count = #entries,
    mode = "floating",
  })
  return true
end

function M:bind(cfg, commands, backend, logger)
  _backend = backend
  _logger = logger
  ensureFocusWatcher()

  local actions = {}
  for name, layout in pairs(cfg.layouts) do
    local capturedName = name
    local capturedLayout = layout
    actions["layout." .. name] = function()
      return runLayout(capturedName, capturedLayout, cfg)
    end
  end

  for action, fn in pairs(actions) do
    commands:register(action, fn, { category = "layout" })
  end

  for _, binding in ipairs(cfg.bindings) do
    if actions[binding.action] then
      _bind.bind(binding.mods or cfg.hyper, binding.key, function()
        commands:execute(binding.action)
      end)
    end
  end
end

function M:stop()
  if _focusWatcher then
    _focusWatcher:unsubscribeAll()
    _focusWatcher = nil
  end
end

return M
