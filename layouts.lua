local config = require("config")
local utils  = require("utils")

local hyper = config.hyper


-- Ensure the app is on screen
local function ensureApp(appName)

  local app = hs.application.get(appName)

  if not app then
    hs.application.launchOrFocus(appName)
    app = hs.application.get(appName)
  end

  return app

end


-- Ensure the app has a window selected
local function ensureWindow(appName)

  local app = ensureApp(appName)
  if not app then return nil end

  local win = app:mainWindow()

  if not win then
    local wins = app:allWindows()
    if #wins > 0 then
      win = wins[1]
    end
  end

  return win

end


-- Snapping function, with optional delay
local function moveAndResize(win, screen, x, y, w, h, delay)
  if not win then return end
  win:moveToScreen(screen)
  -- delay for the move before resize
  hs.timer.doAfter(delay or config.delays.moveResize, function()
    local f = screen:frame()
    win:setFrame({
      x = f.x + f.w * x,
      y = f.y + f.h * y,
      w = f.w * w,
      h = f.h * h,
    })
  end)
end


-- Shortcut to setup dev env
local function devLayout()
  local screens = hs.screen.allScreens()
  if #screens < 2 then
    hs.alert.show("Need 2 monitors for dev layout")
    return
  end
  local monitor1 = screens[1]
  local monitor2 = screens[2]

  local vscode  = ensureWindow(config.apps.editor)    -- VSCode left monitor 1
  local ghostty = ensureWindow(config.apps.terminal)  -- Ghostty right monitor 1
  local firefox = ensureWindow(config.apps.browser)   -- Firefox fullscreen monitor 2

  moveAndResize(firefox, monitor2, 0.0, 0.0, 1.0, 1.0)
  moveAndResize(ghostty, monitor1, 0.5, 0.0, 0.5, 1.0)
  moveAndResize(vscode, monitor1,  0.0, 0.0, 0.5, 1.0, config.delays.vscode)

  if firefox then firefox:focus() end
end


utils.bind(hyper,"D",function()

  hs.application.launchOrFocus(config.apps.browser)
  hs.application.launchOrFocus(config.apps.editor)
  hs.application.launchOrFocus(config.apps.terminal)

  hs.timer.doAfter(config.delays.appLaunch,devLayout)

end)