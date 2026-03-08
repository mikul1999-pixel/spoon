local M = {}
local _spoonPath
function M:init(p) _spoonPath = p end


-- helpers to make sure app windows exist and can move/resize
local function ensureWindow(appName)
  local app = hs.application.get(appName) or hs.application.launchOrFocus(appName) and hs.application.get(appName)
  if not app then return nil end
  return app:mainWindow() or app:allWindows()[1]
end


-- layout functions for specific screen arrangement
local function runLayout(layout, cfg)
  local screens = hs.screen.allScreens()
  for _, slot in ipairs(layout) do
    local screenIdx = math.min(slot.screen, #screens)
    local screen    = screens[screenIdx]
    local appName   = cfg.apps[slot.app]
    local win       = ensureWindow(appName)
    if win then
      win:moveToScreen(screen)
      hs.timer.doAfter(slot.app == "editor" and cfg.delays.vscode or cfg.delays.moveResize, function()
        local f = screen:frame()
        win:setFrame({ x=f.x+f.w*slot.x, y=f.y+f.h*slot.y, w=f.w*slot.w, h=f.h*slot.h })
      end)
    end
  end
end

function M:bind(cfg)
  local utils   = dofile(_spoonPath .. "utils.lua")
  local actions = {}

  for name, layout in pairs(cfg.layouts) do
    local captured = layout
    actions["layout." .. name] = function()
      for _, slot in ipairs(captured) do
        hs.application.launchOrFocus(cfg.apps[slot.app])
      end
      hs.timer.doAfter(cfg.delays.appLaunch, function() runLayout(captured, cfg) end)
    end
  end

  for _, binding in ipairs(cfg.bindings) do
    if actions[binding.action] then
      utils.bind(cfg.hyper, binding.key, actions[binding.action])
    end
  end
end

return M