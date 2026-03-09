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

-- inset a frame: outer gap on screen edges, inner gap as window padding
function M.applyGaps(frame, screenFrame, gaps)
  local o, i = gaps.outer, gaps.inner
  return {
    x = frame.x + (frame.x == screenFrame.x and o or i),
    y = frame.y + (frame.y == screenFrame.y and o or i),
    w = frame.w - o - i,
    h = frame.h - o - i,
  }
end

return M