local M = {}
local _spoonPath
function M:init(p) _spoonPath = p end

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

function M:bind(cfg)
  local u = dofile(_spoonPath .. "utils.lua") -- sibling require
  local h, b, a = cfg.hyper, cfg.bindings, cfg.apps

  local actions = {
    ["app.terminal"] = function() toggleOrCycle(a.terminal) end,
    ["app.editor"]   = function() toggleOrCycle(a.editor) end,
    ["app.browser"]  = function() toggleOrCycle(a.browser) end,
    ["app.newTab"] = function()
        local win = hs.window.focusedWindow()
        if not win then return end
        hs.eventtap.keyStroke({"cmd"}, "T", win:application())
    end,
  }

  for _, binding in ipairs(b) do
    if actions[binding.action] then
      u.bind(h, binding.key, actions[binding.action])
    end
  end
end

return M