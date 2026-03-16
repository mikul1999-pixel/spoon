local M = {}

-- Yabai backend. executes window/workspace/display operations when needed
-- Basically, script yabai (instead of skhd), with user intent assumptions / error handling. Else fallback to hammerspoon for everything
local _path
local _state
local _debug
local _shell
local _logger
local _retryCount
local _placementHorizontalRatio
local _placementVerticalBandRatio
local _placementEdgeWarpPasses
local _policy

local function log(msg)
  if _debug then hs.printf("[wm.yabai] %s", msg) end
end

local function event(level, name, message, data)
  if _logger and _logger[level] then
    _logger[level](_logger, name, message, data)
  end
end

local function msg(args)
  -- Send yabai -m ... command via shell wrapper
  local cmd = { "-m" }
  for _, arg in ipairs(args) do table.insert(cmd, tostring(arg)) end
  local ok, out, code, full = _shell.exec(_path, cmd)
  if not ok then
    log("failed: " .. full .. " -> " .. tostring(out):gsub("\n", " "))
    event("debug", "yabai.command", "command failed", { args = args, output = out, code = code })
  end
  return ok, out, code
end

local function query(args)
  local ok, out = msg(args)
  if not ok then return nil, out end
  if out == nil or out == "" then return nil, "empty output" end
  local decoded = hs.json.decode(out)
  if decoded == nil then return nil, "invalid json" end
  return decoded
end

local function directionName(dir)
  local map = {
    left = "west",
    right = "east",
    up = "north",
    down = "south",
  }
  return map[dir]
end

local function windowSpace(winId)
  local win = query({ "query", "--windows", "--window", tostring(winId) })
  return win and win.space or nil
end

local function windowInfo(winId)
  if winId then
    return query({ "query", "--windows", "--window", tostring(winId) })
  end
  return query({ "query", "--windows", "--window" })
end

local function focusedWindowId()
  local win = windowInfo(nil)
  return win and win.id or nil
end

local function focusWindow(winId)
  if not winId then return false end
  local ok = msg({ "window", "--focus", tostring(winId) })
  return ok and true or false
end

local function displayCount()
  local displays = query({ "query", "--displays" })
  return displays and #displays or 0
end

local function displays()
  return query({ "query", "--displays" }) or {}
end

local function wrappedDisplayTarget(currentDisplay, displaySel)
  if displaySel ~= "next" and displaySel ~= "prev" then
    return tonumber(displaySel)
  end

  local ds = displays()
  if #ds == 0 then return nil end

  local pos = nil
  for i, d in ipairs(ds) do
    if d.index == currentDisplay then
      pos = i
      break
    end
  end

  if not pos then return nil end

  if displaySel == "next" then
    pos = (pos % #ds) + 1
  else
    pos = ((pos - 2 + #ds) % #ds) + 1
  end

  return ds[pos] and ds[pos].index or nil
end

local function runDisplayMove(winId, displaySel)
  local tries = {
    { "window", tostring(winId), "--display", tostring(displaySel) },
    { "window", "--display", tostring(displaySel), "--window", tostring(winId) },
    { "window", "--display", tostring(displaySel) },
  }

  for _, args in ipairs(tries) do
    local ok = msg(args)
    if ok then return true end
  end

  return false
end

local function verifyWindowInSpace(winId, workspaceId)
  for _ = 1, 12 do
    if windowSpace(winId) == workspaceId then return true end
    hs.timer.usleep(120000)
  end
  return false
end

local function moveWindow(winId, workspaceId)
  local tries = {
    { "window", tostring(winId), "--space", tostring(workspaceId) },
    { "window", "--space", tostring(workspaceId), "--window", tostring(winId) },
    { "window", "--focus", tostring(winId) },
  }

  local focused = false
  for i, args in ipairs(tries) do
    local ok = msg(args)
    if i == 3 then
      focused = ok
    elseif ok and verifyWindowInSpace(winId, workspaceId) then
      return true
    end
  end

  if focused then
    local ok = msg({ "window", "--space", tostring(workspaceId) })
    if ok and verifyWindowInSpace(winId, workspaceId) then return true end
  end

  return false
end

local function isFloatingWindow(winId)
  local win = windowInfo(winId)
  if not win then return nil end
  if win["is-floating"] ~= nil then return win["is-floating"] and true or false end
  if win.floating ~= nil then return win.floating and true or false end
  return nil
end

function M:init(ctx)
  _state = ctx.state
  _shell = dofile(ctx.spoonPath .. "utils/shell.lua")
  _path = (ctx.config.yabai and ctx.config.yabai.path) or "/opt/homebrew/bin/yabai"
  _debug = ctx.config.workspaces and ctx.config.workspaces.debug or false
  _retryCount = (ctx.config.behavior and ctx.config.behavior.retryCount) or 2
  _placementHorizontalRatio = (ctx.config.behavior and ctx.config.behavior.placementHorizontalRatio) or 0.5
  _placementVerticalBandRatio = (ctx.config.behavior and ctx.config.behavior.placementVerticalBandRatio) or 0.34
  _placementEdgeWarpPasses = (ctx.config.behavior and ctx.config.behavior.placementEdgeWarpPasses) or 6
  _logger = ctx.logger
  _policy = ctx.policy

  if _policy and _policy.newWindowDefaults then
    local newWindow = _policy:newWindowDefaults()
    local placement = nil
    if newWindow.insertion == "stack_start" then placement = "first_child" end
    if newWindow.insertion == "stack_end" then placement = "second_child" end
    if placement then
      msg({ "config", "window_placement", placement })
    end
  end
end

function M:name()
  return "yabai"
end

function M:focusedWorkspace()
  local space = query({ "query", "--spaces", "--space" })
  local id = space and space.index or nil
  if id and _state and _state.setFocusSnapshot then
    _state:setFocusSnapshot({
      workspaceId = id,
      displayId = space and space.display,
      source = "backend.yabai.focusedWorkspace",
    })
  end
  return id
end

function M:focusWorkspace(workspaceId)
  local ok = msg({ "space", "--focus", tostring(workspaceId) })
  if ok and _state and _state.setCurrentWorkspace then
    _state:setCurrentWorkspace(workspaceId, "backend.yabai.focusWorkspace")
  end
  return ok, ok and nil or "failed to focus workspace"
end

function M:sendWindowToWorkspace(winId, workspaceId, opts)
  if not winId then return false, "missing window id" end

  local ok = moveWindow(winId, workspaceId)
  if not ok then return false, "window did not move to workspace" end

  if _state and _state.setFocusSnapshot then
    _state:setFocusSnapshot({
      windowId = winId,
      workspaceId = workspaceId,
      source = "backend.yabai.sendWindow",
    })
  end

  if opts and opts.sendFollow then
    self:focusWorkspace(workspaceId)
  end
  return true
end

function M:moveWindowToDisplay(winId, displaySel, opts)
  -- Moves a window across displays with verification and wrap-around retry.
  if not winId then return false, "missing window id" end

  local before = windowInfo(winId)
  if not before then return false, "failed to query window before display move" end

  local currentFocus = focusedWindowId()
  if currentFocus ~= winId then focusWindow(winId) end

  local requestedTarget = displaySel
  local ok = runDisplayMove(winId, requestedTarget)

  if not ok then
    if currentFocus and currentFocus ~= winId then focusWindow(currentFocus) end
    return false, "failed to run display move command"
  end

  local moved = false
  for _ = 1, _retryCount + 2 do
    hs.timer.usleep(90000)
    local after = windowInfo(winId)
    if after and after.display and before.display and after.display ~= before.display then
      moved = true
      break
    end
  end

  if not moved then
    local wrapped = wrappedDisplayTarget(before.display, displaySel)
    if wrapped and wrapped ~= before.display then
      requestedTarget = wrapped
      ok = runDisplayMove(winId, wrapped)
      if ok then
        for _ = 1, _retryCount + 2 do
          hs.timer.usleep(90000)
          local after = windowInfo(winId)
          if after and after.display == wrapped then
            moved = true
            break
          end
        end
      end
    end
  end

  if not moved then
    local count = displayCount()
    local relative = displaySel == "next" or displaySel == "prev"
    if relative and count <= 1 then
      moved = true
    elseif tonumber(displaySel) and before.display == tonumber(displaySel) then
      moved = true
    end
  end

  if opts and opts.follow and moved then
    msg({ "display", "--focus", tostring(requestedTarget) })
    focusWindow(winId)
  end

  if currentFocus and currentFocus ~= winId then focusWindow(currentFocus) end

  if moved then
    local after = windowInfo(winId)
    if _state and _state.setFocusSnapshot then
      _state:setFocusSnapshot({
        windowId = winId,
        displayId = after and after.display or tonumber(requestedTarget),
        workspaceId = after and after.space,
        source = "backend.yabai.moveDisplay",
      })
    end
    event("trace", "yabai.display.move", "moved window to display", {
      winId = winId,
      target = requestedTarget,
    })
    return true
  end

  return false, "window display did not change"
end

function M:windowWorkspace(winId)
  if not winId then return nil end
  return windowSpace(winId)
end

function M:isFloating(winId)
  return isFloatingWindow(winId)
end

function M:moveWindowDirection(winId, dir)
  local mapped = directionName(dir)
  if not mapped then return false, "invalid direction" end

  local currentFocus = focusedWindowId()
  if winId and currentFocus ~= winId then focusWindow(winId) end

  local ok = false
  for _ = 1, _retryCount + 1 do
    ok = msg({ "window", "--warp", mapped })
    if ok then break end
    hs.timer.usleep(70000)
  end

  if not ok then
    ok = msg({ "window", "--swap", mapped })
  end

  if currentFocus and currentFocus ~= winId then
    focusWindow(currentFocus)
  end

  if ok then
    event("trace", "yabai.move.direction", "resolved directional move", { direction = dir, winId = winId })
  end
  return ok, ok and nil or "failed to move window direction"
end

function M:placeWindow(winId, dir)
  -- Deterministic placement intent (edge move + normalize ratio)
  local mapped = directionName(dir)
  if not mapped then return false, "invalid direction" end

  local currentFocus = focusedWindowId()
  if winId and currentFocus ~= winId then focusWindow(winId) end

  local moved = false
  for _ = 1, _placementEdgeWarpPasses do
    local ok = msg({ "window", "--warp", mapped })
    if not ok then break end
    moved = true
  end

  if not moved then
    moved = msg({ "window", "--swap", mapped })
  end

  if not moved then
    if currentFocus and currentFocus ~= winId then focusWindow(currentFocus) end
    return false, "failed to place window"
  end

  local ratio = _placementHorizontalRatio
  if dir == "up" then
    ratio = _placementVerticalBandRatio
  elseif dir == "down" then
    ratio = 1 - _placementVerticalBandRatio
  end

  local ratioOk = msg({ "window", "--ratio", string.format("abs:%.2f", ratio) })
  if not ratioOk then
    event("debug", "yabai.place", "ratio adjustment failed", { direction = dir, ratio = ratio })
  end

  if currentFocus and currentFocus ~= winId then
    focusWindow(currentFocus)
  end

  event("trace", "yabai.place", "placed window", {
    direction = dir,
    ratio = ratio,
  })

  return true
end

function M:resizeWindow(winId, dir, step)
  local amount = tonumber(step) or 40
  local edge = {
    left = { "left", -amount, 0 },
    right = { "right", amount, 0 },
    up = { "top", 0, -amount },
    down = { "bottom", 0, amount },
  }
  local e = edge[dir]
  if not e then return false, "invalid direction" end

  local currentFocus = focusedWindowId()
  if winId and currentFocus ~= winId then focusWindow(winId) end

  local ok = false
  for _ = 1, _retryCount + 1 do
    ok = msg({ "window", "--resize", string.format("%s:%d:%d", e[1], e[2], e[3]) })
    if ok then break end
    hs.timer.usleep(70000)
  end

  if currentFocus and currentFocus ~= winId then
    focusWindow(currentFocus)
  end

  return ok, ok and nil or "failed to resize window"
end

function M:focusDirection(dir)
  local mapped = directionName(dir)
  if not mapped then return false, "invalid direction" end
  local ok = msg({ "window", "--focus", mapped })
  return ok, ok and nil or "failed to focus direction"
end

function M:swapDirection(dir)
  local mapped = directionName(dir)
  if not mapped then return false, "invalid direction" end
  local ok = msg({ "window", "--swap", mapped })
  return ok, ok and nil or "failed to swap direction"
end

function M:toggleFloat(winId)
  local args = winId and { "window", tostring(winId), "--toggle", "float" }
    or { "window", "--toggle", "float" }
  local ok = msg(args)
  return ok, ok and nil or "failed to toggle float"
end

function M:toggleFullscreen(winId)
  local args = winId and { "window", tostring(winId), "--toggle", "zoom-fullscreen" }
    or { "window", "--toggle", "zoom-fullscreen" }
  local ok = msg(args)
  return ok, ok and nil or "failed to toggle fullscreen"
end

function M:balanceWorkspace(workspaceId)
  if workspaceId then
    msg({ "space", "--focus", tostring(workspaceId) })
  end
  local ok = msg({ "space", "--balance" })
  return ok, ok and nil or "failed to balance workspace"
end

function M:health()
  local spaces, spacesErr = query({ "query", "--spaces" })
  if not spaces then
    local failed = {
      ok = false,
      backend = "yabai",
      path = _path,
      error = spacesErr,
    }
    if _state and _state.setBackendHealth then
      _state:setBackendHealth(failed, "backend.yabai.health")
    end
    return failed
  end

  local focused = self:focusedWorkspace()
  local healthy = {
    ok = true,
    backend = "yabai",
    path = _path,
    focusedWorkspace = focused,
    workspaceCount = #spaces,
  }
  if _state and _state.setBackendHealth then
    _state:setBackendHealth(healthy, "backend.yabai.health")
  end
  return healthy
end

return M
