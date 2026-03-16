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
    if #windows > 1 then windows[2]:focus()
    else app:hide() end
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
