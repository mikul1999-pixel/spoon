local M = {}
local _spoonPath
function M:init(p) _spoonPath = p end

local _undoFrames = {}  -- [windowId] = frame. written before every snap or resize

local function saveUndo(win)
  if win then _undoFrames[win:id()] = win:frame() end
end

local function snap(win, x, y, w, h)
  if not win then return end
  saveUndo(win)
  local f = win:screen():frame()
  win:setFrame({ x = f.x + f.w*x, y = f.y + f.h*y, w = f.w*w, h = f.h*h })
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

---- resize mode ----
local resizeStep = 40
local resizeMode = hs.hotkey.modal.new()  -- activated via bind()

function resizeMode:entered() hs.alert.show("Resize mode") end
function resizeMode:exited()  hs.alert.show("Exit resize") end

local function addResizeBinds()
  local function r(dx, dy, dw, dh)
    local win = hs.window.focusedWindow()
    if not win then return end
    saveUndo(win)
    local f = win:frame()
    win:setFrame({ x=f.x+dx, y=f.y+dy, w=f.w+dw, h=f.h+dh })
  end
  resizeMode:bind("","H", function() r(0,0,-resizeStep,0) end)
  resizeMode:bind("","L", function() r(0,0, resizeStep,0) end)
  resizeMode:bind("","K", function() r(0,0,0,-resizeStep) end)
  resizeMode:bind("","J", function() r(0,0,0, resizeStep) end)
  resizeMode:bind("","escape", function() resizeMode:exit() end)
end

function M:bind(cfg)
  local utils = dofile(_spoonPath .. "utils.lua")
  local h, b  = cfg.hyper, cfg.bindings

  addResizeBinds()

  local actions = {
    ["win.snapLeft"]    = function() snap(utils.focused(), 0,   0,   0.5, 1)   end,
    ["win.snapRight"]   = function() snap(utils.focused(), 0.5, 0,   0.5, 1)   end,
    ["win.snapTop"]     = function() snap(utils.focused(), 0,   0,   1,   0.5) end,
    ["win.snapBottom"]  = function() snap(utils.focused(), 0,   0.5, 1,   0.5) end,
    ["win.maximize"]    = function()
      local w = utils.focused(); if w then saveUndo(w); w:maximize() end
    end,
    ["win.center"]      = function() snap(utils.focused(), 0.1, 0.1, 0.8, 0.8) end,
    ["win.undo"]        = function()
      local w = utils.focused()
      if w and _undoFrames[w:id()] then w:setFrame(_undoFrames[w:id()]) end
    end,
    ["win.nextMonitor"] = function()
      local w = utils.focused(); if w then w:moveToScreen(w:screen():next()) end
    end,
    ["win.prevMonitor"] = function()
      local w = utils.focused(); if w then w:moveToScreen(w:screen():previous()) end
    end,
    ["win.nextScreen"]  = focusNextScreen,
    ["win.cycleLocal"]  = cycleWindowsOnScreen,
    ["win.resizeMode"]  = function() resizeMode:enter() end,
  }

  for _, binding in ipairs(b) do
    if actions[binding.action] then
      utils.bind(h, binding.key, actions[binding.action])
    end
  end
end

return M