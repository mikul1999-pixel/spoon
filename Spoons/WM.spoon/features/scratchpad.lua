local M = {}

-- Scratchpad manager to store / fetch windows
local _spoonPath
local _bind
local _alerts
local _cfg
local _state
local _backend
local _logger

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

local _scratchpads = {}

local function getLastIndex()
  if _state and _state.scratchpadLastIndex then
    return _state:scratchpadLastIndex()
  end
  return 0
end

local function setLastIndex(value)
  if _state and _state.setScratchpadLastIndex then
    _state:setScratchpadLastIndex(value)
  end
end

local function defaults()
  return {
    useWorkspaceTransport = false,
    workspace = 9,
    retrieveTarget = "current",
    followOnRetrieve = false,
    fallbackMinimize = true,
  }
end

local function mergedConfig(cfg)
  local tableUtil = dofile(_spoonPath .. "utils/table.lua")
  return tableUtil.merge(defaults(), cfg or {})
end

local function getWin(entry)
  if entry.win and entry.win:id() then return entry.win end
  return hs.window.get(entry.id)
end

local function removeById(winId)
  for i, s in ipairs(_scratchpads) do
    if s.id == winId then
      if s.watcher then s.watcher:stop() end
      table.remove(_scratchpads, i)
      _state:removeScratchOrigin(winId)
      local idx = getLastIndex()
      if idx >= i then setLastIndex(math.max(0, idx - 1)) end
      return
    end
  end
end

local function watchWindow(win)
  local watcher = win:newWatcher(function(_, event, _, id)
    if event == hs.uielement.watcher.elementDestroyed then
      removeById(id)
    end
  end, win:id())
  watcher:start({ hs.uielement.watcher.elementDestroyed })
  return watcher
end

local function scratchWorkspace()
  return _cfg.workspace or 9
end

local function currentWorkspace()
  return _backend:focusedWorkspace() or _state:currentWorkspace() or 1
end

local function workspaceHidden(entry)
  local ws = _backend:windowWorkspace(entry.id)
  return ws == scratchWorkspace()
end

local function retrieveWorkspace(entry)
  local target = currentWorkspace()
  if _cfg.retrieveTarget == "origin" then
    target = _state:scratchOrigin(entry.id) or entry.originWorkspace or target
  end
  return target
end

local function raiseAndFocus(win)
  if not win then return end
  if win.raise then win:raise() end
  win:focus()
end

local function toWorkspace(entry, workspaceId, opts)
  -- Sends scratchpad window via backend; falls back to minimize when needed.
  local ok = _backend:sendWindowToWorkspace(entry.id, workspaceId, opts or {})
  if ok then return true end

  local win = getWin(entry)
  if win and _cfg.fallbackMinimize then
    win:minimize()
    entry.mode = "minimize"
    if _logger then
      _logger:info("scratchpad.fallback", "transport failed, minimized window", {
        winId = entry.id,
        workspace = workspaceId,
      })
    end
  end
  return false
end

function M:add()
  local win = hs.window.focusedWindow()
  if not win then return end

  local winId = win:id()
  for _, s in ipairs(_scratchpads) do
    if s.id == winId then
      _alerts.warn("Already in scratchpad")
      return
    end
  end

  local originWorkspace = currentWorkspace()
  local entry = {
    id = winId,
    win = win,
    frame = win:frame(),
    screen = win:screen(),
    watcher = watchWindow(win),
    originWorkspace = originWorkspace,
    mode = "workspace",
  }

  _state:setScratchOrigin(winId, originWorkspace)

  if _cfg.useWorkspaceTransport then
    local ok = toWorkspace(entry, scratchWorkspace(), { sendFollow = false })
    if not ok then entry.mode = "minimize" end
  else
    entry.mode = "minimize"
    win:minimize()
  end

  table.insert(_scratchpads, entry)
  _alerts.show("Added " .. (win:application() and win:application():name() or "window") .. " to scratchpad")
end

function M:toggle()
  -- Cycles scratchpad windows between hidden and visible states.
  if #_scratchpads == 0 then _alerts.warn("No scratchpads"); return end

  local function isHidden(entry)
    local win = getWin(entry)
    if not win then return false end
    if entry.mode == "workspace" then return workspaceHidden(entry) end
    return win:isMinimized()
  end

  local function hide(entry)
    local win = getWin(entry)
    if not win then return end
    if entry.mode == "workspace" then
      toWorkspace(entry, scratchWorkspace(), { sendFollow = false })
    else
      win:minimize()
    end
  end

  local function show(entry)
    local win = getWin(entry)
    if not win then return end

    if entry.mode == "workspace" then
      local target = retrieveWorkspace(entry)
      toWorkspace(entry, target, { sendFollow = _cfg.followOnRetrieve })
    else
      local target = retrieveWorkspace(entry)
      local moved = false
      if _backend and target then
        moved = _backend:sendWindowToWorkspace(entry.id, target, { sendFollow = false }) == true
      end
      win:unminimize()
      if (not moved) and _backend and target then
        _backend:sendWindowToWorkspace(entry.id, target, { sendFollow = false })
      end
    end

    local isFloating = _backend:isFloating(entry.id)
    if isFloating == true then
      win:moveToScreen(entry.screen)
      win:setFrame(entry.frame)
      win:setFullScreen(false)
    end
    raiseAndFocus(win)
  end

  local currentIndex = getLastIndex()
  if currentIndex > 0 and currentIndex <= #_scratchpads then
    local s = _scratchpads[currentIndex]
    if not isHidden(s) then
      hide(s)
      return
    end
  end

  local start = (currentIndex % #_scratchpads) + 1
  for offset = 0, #_scratchpads - 1 do
    local i = (start + offset - 1) % #_scratchpads + 1
    local s = _scratchpads[i]
    if isHidden(s) then
      setLastIndex(i)
      show(s)
      return
    end
  end

  _alerts.warn("No scratchpads hidden")
end

function M:bind(cfg, commands, state, backend, logger)
  _cfg = mergedConfig(cfg.scratchpad)
  _state = state
  _backend = backend
  _logger = logger

  local actions = {
    ["scratchpad.add"] = function() self:add() end,
    ["scratchpad.toggle"] = function() self:toggle() end,
  }

  for action, fn in pairs(actions) do
    commands:register(action, fn, { category = "scratchpad" })
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
