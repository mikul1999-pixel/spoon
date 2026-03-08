local M = {}
local _spoonPath
function M:init(p) _spoonPath = p end

-- helpers to make sure app windows exist and can move/resize
local function ensureWindow(appName)
  local app = hs.application.get(appName) or hs.application.launchOrFocus(appName) and hs.application.get(appName)
  if not app then return nil end
  return app:mainWindow() or app:allWindows()[1]
end

local function moveAndResize(win, screen, x, y, w, h, delay)
  if not win then return end
  win:moveToScreen(screen)
  hs.timer.doAfter(delay or 0, function()
    local f = screen:frame()
    win:setFrame({ x=f.x+f.w*x, y=f.y+f.h*y, w=f.w*w, h=f.h*h })
  end)
end


-- layout functions for specific screen arrangement
local function devLayout(cfg)
  local screens = hs.screen.allScreens()
  if #screens < 2 then hs.alert.show("Need 2 monitors for dev layout"); return end
  local m1, m2 = screens[1], screens[2]
  local a = cfg.apps
  local vscode  = ensureWindow(a.editor)
  local ghostty = ensureWindow(a.terminal)
  local firefox = ensureWindow(a.browser)
  moveAndResize(firefox, m2, 0  , 0, 1  , 1, cfg.delays.moveResize)
  moveAndResize(ghostty, m1, 0.5, 0, 0.5, 1, cfg.delays.moveResize)
  moveAndResize(vscode,  m1, 0  , 0, 0.5, 1, cfg.delays.vscode)
  if firefox then firefox:focus() end
end

function M:bind(cfg)
  local utils = dofile(_spoonPath .. "utils.lua")
  local h, b  = cfg.hyper, cfg.bindings

  local actions = {
    ["layout.dev"] = function()
      hs.application.launchOrFocus(cfg.apps.browser)
      hs.application.launchOrFocus(cfg.apps.editor)
      hs.application.launchOrFocus(cfg.apps.terminal)
      hs.timer.doAfter(cfg.delays.appLaunch, function() devLayout(cfg) end)
    end,
  }

  for _, binding in ipairs(b) do
    if actions[binding.action] then
      utils.bind(h, binding.key, actions[binding.action])
    end
  end
end

return M