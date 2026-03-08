local config = require("config")
local utils  = require("utils")

local hyper = config.hyper


local function snap(x,y,w,h)

  local win = utils.focused()
  if not win then return end

  local screen = win:screen()
  local f = screen:frame()

  win:setFrame({
    x = f.x + f.w*x,
    y = f.y + f.h*y,
    w = f.w*w,
    h = f.h*h
  })

end

-- snapping
utils.bind(hyper,"H",function() snap(0,0,0.5,1) end)
utils.bind(hyper,"L",function() snap(0.5,0,0.5,1) end)
utils.bind(hyper,"K",function() snap(0,0,1,0.5) end)
utils.bind(hyper,"J",function() snap(0,0.5,1,0.5) end)

utils.bind(hyper,"F",function()
  local win = utils.focused()
  if win then win:maximize() end
end)

-- move between monitors
utils.bind(hyper,"N",function()
  local win = utils.focused()
  if win then win:moveToScreen(win:screen():next()) end
end)

utils.bind(hyper,"P",function()
  local win = utils.focused()
  if win then win:moveToScreen(win:screen():previous()) end
end)

-- cycle focus to next screen
local function focusNextScreen()

  local win = utils.focused()
  if not win then return end

  local nextScreen = win:screen():next()

  local windows = hs.window.orderedWindows()

  for _,w in ipairs(windows) do
    if w:screen() == nextScreen then
      w:focus()
      return
    end
  end

end

utils.bind(config.hyper,"tab",focusNextScreen)

-- cycle windows on current screen
local function cycleWindowsOnScreen()
  local focused = utils.focused()
  if not focused then return end
  local screen = focused:screen()
  local wins = hs.window.orderedWindows()
  local onScreen = {}
  for _, w in ipairs(wins) do
    if w:screen() == screen and w:isVisible() then
      table.insert(onScreen, w)
    end
  end
  if #onScreen < 2 then return end
  for i, w in ipairs(onScreen) do
    if w:id() == focused:id() then
      onScreen[(i % #onScreen) + 1]:focus()
      return
    end
  end
end

utils.bind(config.hyper, "`", cycleWindowsOnScreen)


---- resize mode ----

local resizeStep = 40

resizeMode = hs.hotkey.modal.new(config.hyper, "R")

function resizeMode:entered()
  hs.alert.show("Resize mode")
end

function resizeMode:exited()
  hs.alert.show("Exit resize")
end

local function resize(dx,dy,dw,dh)

  local win = utils.focused()
  if not win then return end

  local f = win:frame()

  f.x = f.x + dx
  f.y = f.y + dy
  f.w = f.w + dw
  f.h = f.h + dh

  win:setFrame(f)

end

-- shrink width
resizeMode:bind("", "H", function()
  resize(0,0,-resizeStep,0)
end)

-- grow width
resizeMode:bind("", "L", function()
  resize(0,0,resizeStep,0)
end)

-- shrink height
resizeMode:bind("", "K", function()
  resize(0,0,0,-resizeStep)
end)

-- grow height
resizeMode:bind("", "J", function()
  resize(0,0,0,resizeStep)
end)

resizeMode:bind("", "escape", function()
  resizeMode:exit()
end)