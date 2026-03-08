local M = {}

function M.bind(mods, key, fn)
  hs.hotkey.bind(mods, key, fn)
end

function M.focused()  return hs.window.focusedWindow() end
function M.screens()  return hs.screen.allScreens() end
function M.primary()  return hs.screen.primaryScreen() end

function M.secondary()
  for _, s in ipairs(hs.screen.allScreens()) do
    if s ~= hs.screen.primaryScreen() then return s end
  end
  return hs.screen.primaryScreen()
end

-- resolve a binding entry by action string
function M.findBinding(bindings, action)
  for _, b in ipairs(bindings) do
    if b.action == action then return b end
  end
end

return M