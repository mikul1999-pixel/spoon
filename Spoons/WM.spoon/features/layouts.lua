local M = {}

-- Applies preset app layouts across screens
local _spoonPath
local _bind
local _frame

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _frame = dofile(_spoonPath .. "utils/frame.lua")
end

local function ensureWindow(appName)
  local app = hs.application.get(appName) or hs.application.launchOrFocus(appName) and hs.application.get(appName)
  if not app then return nil end
  return app:mainWindow() or app:allWindows()[1]
end

local function runLayout(layout, cfg)
  local screens = hs.screen.allScreens()
  for _, slot in ipairs(layout) do
    local screenIdx = math.min(slot.screen, #screens)
    local screen = screens[screenIdx]
    local appName = cfg.apps[slot.app]
    local win = ensureWindow(appName)
    if win then
      win:moveToScreen(screen)
      hs.timer.doAfter(slot.app == "editor" and cfg.delays.vscode or cfg.delays.moveResize, function()
        local f = screen:frame()
        local raw = { x = f.x + f.w * slot.x, y = f.y + f.h * slot.y, w = f.w * slot.w, h = f.h * slot.h }
        win:setFrame(_frame.applyGaps(raw, f, cfg.gaps))
      end)
    end
  end
end

function M:bind(cfg, commands)
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

return M
