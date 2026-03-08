local M = {}

function M.bind(mods,key,fn)
  hs.hotkey.bind(mods,key,fn)
end

function M.focused()
  return hs.window.focusedWindow()
end

function M.screens()
  return hs.screen.allScreens()
end

function M.primary()
  return hs.screen.primaryScreen()
end

function M.secondary()
  local screens = hs.screen.allScreens()
  if #screens < 2 then
    return screens[1]
  end

  for _,s in ipairs(screens) do
    if s ~= hs.screen.primaryScreen() then
      return s
    end
  end
end

return M