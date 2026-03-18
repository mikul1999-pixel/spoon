local M = {}

-- App-specific shortcuts
local _spoonPath
local _bind
local _alerts

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

local function appWindowsInOrder(appName, app)
  local ordered = {}
  for _, win in ipairs(hs.window.orderedWindows() or {}) do
    local winApp = win:application()
    if winApp and winApp:name() == appName and not win:isMinimized() and win:isVisible() then
      table.insert(ordered, win)
    end
  end

  if #ordered > 0 then return ordered end

  local fallback = {}
  for _, win in ipairs(app:allWindows() or {}) do
    if not win:isMinimized() then
      table.insert(fallback, win)
    end
  end
  return fallback
end

local function toggleOrCycle(appName)
  local app = hs.application.get(appName)
  if not app then
    hs.application.launchOrFocus(appName)
    return
  end

  local windows = appWindowsInOrder(appName, app)
  if #windows == 0 then
    hs.application.launchOrFocus(appName)
    return
  end

  local focused = hs.window.focusedWindow()
  local focusedApp = focused and focused:application()
  if focusedApp and focusedApp:name() == appName then
    if #windows == 1 then
      app:hide()
      return
    end

    local nextIndex = 1
    local focusedId = focused:id()
    for i, win in ipairs(windows) do
      if win:id() == focusedId then
        nextIndex = (i % #windows) + 1
        break
      end
    end
    windows[nextIndex]:focus()
  else
    windows[1]:focus()
  end
end

function M:bind(cfg, commands)
  local a = cfg.apps
  local actions = {
    ["app.terminal"] = function() toggleOrCycle(a.terminal) end,
    ["app.editor"] = function() toggleOrCycle(a.editor) end,
    ["app.browser"] = function() toggleOrCycle(a.browser) end,
    ["app.newTab"] = function()
      local win = hs.window.focusedWindow()
      if not win then return end
      hs.eventtap.keyStroke({ "cmd" }, "T", win:application())
    end,
    ["app.newWindow"] = function()
      local win = hs.window.focusedWindow()
      if not win then
        _alerts.warn("No focused app for new window")
        return false
      end

      local app = win:application()
      if not app then
        _alerts.warn("No focused app for new window")
        return false
      end

      hs.eventtap.keyStroke({ "cmd" }, "N", app)
      return true
    end,
  }

  for action, fn in pairs(actions) do
    commands:register(action, fn, { category = "app" })
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
