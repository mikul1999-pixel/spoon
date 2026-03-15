local M = {}

-- Workspace/mode feature with directional focus/swap and intelligent fallback
local _spoonPath
local _bind
local _alerts
local _logger
local _backend
local _state
local _cfg
local _modes
local _modeWindowId

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

local function logInfo(event, message, data)
  if _logger and _logger.info then _logger:info(event, message, data) end
end

local function logWarn(event, message, data)
  if _logger and _logger.warn then _logger:warn(event, message, data) end
end

local function focusedWindow()
  return hs.window.focusedWindow()
end

local function focusedWindowId()
  local win = focusedWindow()
  if not win then return nil end
  return win:id()
end

local function sendTargetWindowId()
  if _modeWindowId then
    local captured = hs.window.get(_modeWindowId)
    if captured then return captured:id() end
  end
  return focusedWindowId()
end

local function directionalTarget(win, dir)
  local wf = win:frame()
  local wcx = wf.x + wf.w / 2
  local wcy = wf.y + wf.h / 2
  local screen = win:screen()

  local candidates = hs.fnutils.filter(hs.window.orderedWindows(), function(w)
    return w:id() ~= win:id() and w:isVisible() and not w:isMinimized() and w:screen() == screen
  end)

  local bestWindow = nil
  local bestScore = nil

  for _, candidate in ipairs(candidates) do
    local cf = candidate:frame()
    local ccx = cf.x + cf.w / 2
    local ccy = cf.y + cf.h / 2
    local dx = ccx - wcx
    local dy = ccy - wcy

    local primary = nil
    local secondary = nil
    if dir == "left" and dx < 0 then
      primary = -dx
      secondary = math.abs(dy)
    elseif dir == "right" and dx > 0 then
      primary = dx
      secondary = math.abs(dy)
    elseif dir == "up" and dy < 0 then
      primary = -dy
      secondary = math.abs(dx)
    elseif dir == "down" and dy > 0 then
      primary = dy
      secondary = math.abs(dx)
    end

    if primary then
      local score = primary + secondary * 0.35
      if not bestScore or score < bestScore then
        bestScore = score
        bestWindow = candidate
      end
    end
  end

  return bestWindow
end

local function ensureFloating(win)
  local status = _backend:isFloating(win:id())
  if status == true then return true end

  local ok = _backend:toggleFloat(win:id())
  if not ok then return false end

  hs.timer.usleep(60000)
  return _backend:isFloating(win:id()) == true
end

local function swapFloatingFrames(dir)
  local source = focusedWindow()
  if not source then return false, "No focused window" end

  local target = directionalTarget(source, dir)
  if not target then return false, "No window " .. dir end

  if not ensureFloating(source) then
    return false, "Failed to float source window"
  end

  if not ensureFloating(target) then
    return false, "Failed to float target window"
  end

  local sourceFrame = source:frame()
  local targetFrame = target:frame()
  source:setFrame(targetFrame)
  target:setFrame(sourceFrame)
  source:focus()

  logInfo("workspace.swap", "swapped floating window frames", {
    direction = dir,
    source = source:id(),
    target = target:id(),
  })
  return true
end

local function run(ok, err, fallback)
  if not ok then
    _alerts.warn(err or fallback)
    return false
  end
  return true
end

local function runDirectional(kind, dir, fn)
  local ok, err, resolved = fn(dir)
  if ok then
    if resolved and resolved ~= dir then
      logInfo("workspace." .. kind, "directional fallback applied", {
        requested = dir,
        resolved = resolved,
      })
    end
    return true
  end
  _alerts.warn(err or (kind .. " failed"))
  return false
end

local function swapDirectional(dir)
  local win = focusedWindow()
  if not win then
    _alerts.warn("No focused window")
    return
  end

  local focusedFloating = _backend:isFloating(win:id()) == true
  if focusedFloating then
    local ok, err = swapFloatingFrames(dir)
    if ok then return end
    logWarn("workspace.swap", "floating swap failed, trying tiled swap", {
      direction = dir,
      error = err,
    })
  end

  local ok, err, resolved = _backend:swapDirection(dir)
  if ok then
    if resolved and resolved ~= dir then
      logInfo("workspace.swap", "directional fallback applied", {
        requested = dir,
        resolved = resolved,
      })
    end
    return
  end

  if not focusedFloating and _cfg.behavior and _cfg.behavior.autoFloatOnMoveFailure then
    local toggleOk = _backend:toggleFloat(win:id())
    if toggleOk then
      hs.timer.usleep(60000)
      local ok, err = swapFloatingFrames(dir)
      if ok then
        logInfo("workspace.swap", "fallback to floating swap", { direction = dir })
        return
      end
      _alerts.warn(err or "Swap failed")
      return
    end
  end

  _alerts.warn(err or "Swap failed")
end

local function ensureModes(commands, actions, count)
  if not _modes then return end

  local workspaceBindings = {
    { key = "h", fn = function() commands:execute("workspace.focus.prev") end },
    { key = "l", fn = function() commands:execute("workspace.focus.next") end },
    { key = "space", fn = function() commands:execute("workspace.toggleFloat") end },
    { key = "f", fn = function() commands:execute("workspace.toggleFullscreen") end },
    { key = "b", fn = function() commands:execute("workspace.balance") end },
  }

  local sendBindings = {}
  for i = 1, count do
    local key = tostring(i)
    table.insert(workspaceBindings, {
      key = key,
      fn = function() commands:execute("workspace.focus." .. i) end,
      exit = true,
    })
    table.insert(sendBindings, {
      key = key,
      fn = function() commands:execute("workspace.send." .. i) end,
      exit = true,
    })
  end

  _modes:register("workspace", {
    enterMessage = "Workspace mode: 1-9, h/l, f, space, b",
    exitMessage = "Exit workspace mode",
    bindings = workspaceBindings,
  })

  _modes:register("send", {
    enterMessage = "Workspace send mode: 1-9",
    exitMessage = "Exit send mode",
    onEnter = function() _modeWindowId = focusedWindowId() end,
    onExit = function() _modeWindowId = nil end,
    bindings = sendBindings,
  })

  _modes:register("focus", {
    enterMessage = "Focus mode: h/j/k/l",
    exitMessage = "Exit focus mode",
    onDirection = function(dir)
      commands:execute("workspace.focus." .. dir)
    end,
  })

  _modes:register("swap", {
    enterMessage = "Swap mode: h/j/k/l",
    exitMessage = "Exit swap mode",
    onDirection = function(dir)
      commands:execute("workspace.swap." .. dir)
    end,
    bindings = {
      { key = "b", fn = function() commands:execute("workspace.balance") end },
    },
  })

  actions["workspace.mode"] = function() _modes:enter("workspace") end
  actions["workspace.sendMode"] = function() _modes:enter("send") end
  actions["workspace.focusMode"] = function() _modes:enter("focus") end
  actions["workspace.swapMode"] = function() _modes:enter("swap") end
end

function M:bind(cfg, commands, state, backend, logger, modes)
  _logger = logger
  _backend = backend
  _state = state
  _cfg = cfg
  _modes = modes

  local wc = cfg.workspaces or {}
  local count = wc.count or 9
  local sendFollow = wc.sendFollow or false

  local actions = {
    ["workspace.focus.left"] = function() runDirectional("focus", "left", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.focus.right"] = function() runDirectional("focus", "right", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.focus.up"] = function() runDirectional("focus", "up", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.focus.down"] = function() runDirectional("focus", "down", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.swap.left"] = function() swapDirectional("left") end,
    ["workspace.swap.right"] = function() swapDirectional("right") end,
    ["workspace.swap.up"] = function() swapDirectional("up") end,
    ["workspace.swap.down"] = function() swapDirectional("down") end,
    ["workspace.toggleFloat"] = function() run(backend:toggleFloat(focusedWindowId()), "Toggle float failed") end,
    ["workspace.toggleFullscreen"] = function() run(backend:toggleFullscreen(focusedWindowId()), "Toggle fullscreen failed") end,
    ["workspace.balance"] = function()
      run(backend:balanceWorkspace(backend:focusedWorkspace()), "Balance failed")
    end,
    ["workspace.focus.prev"] = function()
      local current = backend:focusedWorkspace() or state:currentWorkspace() or 1
      local prev = current - 1
      if prev < 1 then prev = count end
      local ok, err = backend:focusWorkspace(prev)
      if ok then
        state:setCurrentWorkspace(prev)
      else
        _alerts.warn(err or "Focus previous workspace failed")
      end
    end,
    ["workspace.focus.next"] = function()
      local current = backend:focusedWorkspace() or state:currentWorkspace() or 1
      local nxt = current + 1
      if nxt > count then nxt = 1 end
      local ok, err = backend:focusWorkspace(nxt)
      if ok then
        state:setCurrentWorkspace(nxt)
      else
        _alerts.warn(err or "Focus next workspace failed")
      end
    end,
  }

  for i = 1, count do
    local focusName = "workspace.focus." .. i
    local sendName = "workspace.send." .. i

    actions[focusName] = function()
      local ok, err = backend:focusWorkspace(i)
      if not ok then
        _alerts.warn(err or ("Failed to focus workspace " .. i))
        return
      end
      state:setCurrentWorkspace(i)
    end

    actions[sendName] = function()
      local winId = sendTargetWindowId()
      if not winId then
        _alerts.warn("No focused window to send")
        return
      end
      local ok, err = backend:sendWindowToWorkspace(winId, i, { sendFollow = sendFollow })
      if not ok then _alerts.warn(err or ("Failed to send window to workspace " .. i)) end
    end
  end

  ensureModes(commands, actions, count)

  for action, fn in pairs(actions) do
    commands:register(action, fn, { category = "workspace" })
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
