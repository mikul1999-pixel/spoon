local M = {}

-- Workspace/mode feature. Use mac Spaces to mirror linux desktop workspaces
local _spoonPath
local _bind
local _alerts
local _workspaceMode
local _sendMode
local _focusMode
local _swapMode
local _modeWindowId
local _logger

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

local function logInfo(event, message, data)
  if _logger and _logger.info then _logger:info(event, message, data) end
end

local function focusedWindowId()
  local win = hs.window.focusedWindow()
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

local function ensureModes(commands, actions, count)
  -- Creates workspace, send, focus, and swap modes once.
  if _workspaceMode and _sendMode and _focusMode and _swapMode then return end

  _workspaceMode = hs.hotkey.modal.new()
  _sendMode = hs.hotkey.modal.new()
  _focusMode = hs.hotkey.modal.new()
  _swapMode = hs.hotkey.modal.new()

  function _workspaceMode:entered()
    _alerts.show("Workspace mode: 1-9, h/l, f, space")
  end

  function _sendMode:entered()
    _modeWindowId = focusedWindowId()
    _alerts.show("Workspace send mode: 1-9")
  end

  function _focusMode:entered()
    _alerts.show("Focus mode: h/j/k/l")
  end

  function _swapMode:entered()
    _alerts.show("Swap mode: h/j/k/l")
  end

  for i = 1, count do
    local key = tostring(i)
    local focusName = "workspace.focus." .. i
    local sendName = "workspace.send." .. i

    _workspaceMode:bind("", key, function()
      commands:execute(focusName)
      _workspaceMode:exit()
    end)

    _sendMode:bind("", key, function()
      commands:execute(sendName)
      _sendMode:exit()
      _modeWindowId = nil
    end)
  end

  _workspaceMode:bind("", "h", function() commands:execute("workspace.focus.prev") end)
  _workspaceMode:bind("", "l", function() commands:execute("workspace.focus.next") end)
  _workspaceMode:bind("", "space", function() commands:execute("workspace.toggleFloat") end)
  _workspaceMode:bind("", "f", function() commands:execute("workspace.toggleFullscreen") end)
  _workspaceMode:bind("", "b", function() commands:execute("workspace.balance") end)

  _focusMode:bind("", "h", function() commands:execute("workspace.focus.left") end)
  _focusMode:bind("", "j", function() commands:execute("workspace.focus.down") end)
  _focusMode:bind("", "k", function() commands:execute("workspace.focus.up") end)
  _focusMode:bind("", "l", function() commands:execute("workspace.focus.right") end)

  _swapMode:bind("", "h", function() commands:execute("workspace.swap.left") end)
  _swapMode:bind("", "j", function() commands:execute("workspace.swap.down") end)
  _swapMode:bind("", "k", function() commands:execute("workspace.swap.up") end)
  _swapMode:bind("", "l", function() commands:execute("workspace.swap.right") end)
  _swapMode:bind("", "b", function() commands:execute("workspace.balance") end)

  _workspaceMode:bind("", "escape", function() _workspaceMode:exit() end)
  _sendMode:bind("", "escape", function() _sendMode:exit() end)
  _focusMode:bind("", "escape", function() _focusMode:exit() end)
  _swapMode:bind("", "escape", function() _swapMode:exit() end)

  actions["workspace.mode"] = function() _workspaceMode:enter() end
  actions["workspace.sendMode"] = function() _sendMode:enter() end
  actions["workspace.focusMode"] = function() _focusMode:enter() end
  actions["workspace.swapMode"] = function() _swapMode:enter() end
end

function M:bind(cfg, commands, state, backend, logger)
  -- Registers workspace actions and binds configured hotkeys.
  _logger = logger
  local wc = cfg.workspaces or {}
  local count = wc.count or 9
  local sendFollow = wc.sendFollow or false

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

  local actions = {
    ["workspace.focus.left"] = function() runDirectional("focus", "left", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.focus.right"] = function() runDirectional("focus", "right", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.focus.up"] = function() runDirectional("focus", "up", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.focus.down"] = function() runDirectional("focus", "down", function(dir) return backend:focusDirection(dir) end) end,
    ["workspace.swap.left"] = function() runDirectional("swap", "left", function(dir) return backend:swapDirection(dir) end) end,
    ["workspace.swap.right"] = function() runDirectional("swap", "right", function(dir) return backend:swapDirection(dir) end) end,
    ["workspace.swap.up"] = function() runDirectional("swap", "up", function(dir) return backend:swapDirection(dir) end) end,
    ["workspace.swap.down"] = function() runDirectional("swap", "down", function(dir) return backend:swapDirection(dir) end) end,
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
      if ok then state:setCurrentWorkspace(prev) else _alerts.warn(err or "Focus previous workspace failed") end
    end,
    ["workspace.focus.next"] = function()
      local current = backend:focusedWorkspace() or state:currentWorkspace() or 1
      local nxt = current + 1
      if nxt > count then nxt = 1 end
      local ok, err = backend:focusWorkspace(nxt)
      if ok then state:setCurrentWorkspace(nxt) else _alerts.warn(err or "Focus next workspace failed") end
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
