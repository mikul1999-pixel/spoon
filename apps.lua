local config = require("config")
local utils  = require("utils")

local hyper = config.hyper


-- Launch or focus an app
local function toggleOrCycle(appName)

  local app = hs.application.get(appName)

  if not app then
    hs.application.launchOrFocus(appName)
    return
  end

  local windows = app:allWindows()

  if #windows == 0 then
    hs.application.launchOrFocus(appName)
    return
  end

  local focused = hs.window.focusedWindow()

  if focused and focused:application():name() == appName then

    if #windows > 1 then
      windows[2]:focus()
    else
      app:hide()
    end

  else
    windows[1]:focus()
  end

end


utils.bind(hyper,"T",function()
  toggleOrCycle(config.apps.terminal)
end)

utils.bind(hyper,"E",function()
  toggleOrCycle(config.apps.editor)
end)

utils.bind(hyper,"B",function()
  toggleOrCycle(config.apps.browser)
end)