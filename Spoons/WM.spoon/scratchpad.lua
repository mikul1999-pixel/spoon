local M = {}
local _spoonPath

function M:init(p) _spoonPath = p end

local _scratchpads = {}  -- { id, win, frame, screen, watcher }
local _lastIndex   = 0

local function showAlert(msg, duration)
  hs.alert.show(msg, { textSize = 16 }, duration or 0.5)
end

local function removeById(winId)
  for i, s in ipairs(_scratchpads) do
    if s.id == winId then
      if s.watcher then s.watcher:stop() end
      table.remove(_scratchpads, i)
      if _lastIndex >= i then _lastIndex = math.max(0, _lastIndex - 1) end
      return
    end
  end
end

local function watchWindow(win)
  local watcher = win:newWatcher(function(_, event, _, id)
    if event == hs.uielement.watcher.elementDestroyed then
      removeById(id)
    end
  end, win:id())
  watcher:start({ hs.uielement.watcher.elementDestroyed })
  return watcher
end

function M:add()
  local win = hs.window.focusedWindow()
  if not win then return end
  local winId = win:id()
  for _, s in ipairs(_scratchpads) do
    if s.id == winId then
      local names = {}
      for _, sp in ipairs(_scratchpads) do
        local title = sp.win:title():sub(1, 30):lower()
        table.insert(names, sp.win:application():name() .. ": " .. title)
      end
      showAlert("In scratchpad \n • " .. table.concat(names, "\n • "), 1.0)
      return
    end
  end
  table.insert(_scratchpads, {
    id      = winId,
    win     = win,
    frame   = win:frame(),
    screen  = win:screen(),
    watcher = watchWindow(win),
  })
  win:minimize() -- since hide() is app level, need to use minimize
  showAlert("Added " .. win:application():name() .. " to scratchpad")
end

function M:toggle()
  if #_scratchpads == 0 then showAlert("No scratchpads"); return end

  local function show(s)
    s.win:moveToScreen(s.screen)
    s.win:setFrame(s.frame)
    s.win:setFullScreen(false)
    s.win:becomeMain()
    s.win:unminimize()
  end

  -- minimize if last shown is visible
  if _lastIndex > 0 and _lastIndex <= #_scratchpads then
    local s = _scratchpads[_lastIndex]
    if not s.win:isMinimized() then
      s.win:minimize()
      return
    end
  end

  -- show next minimized scratchpad. cycle through
  local start = (_lastIndex % #_scratchpads) + 1
  for offset = 0, #_scratchpads - 1 do
    local i = (start + offset - 1) % #_scratchpads + 1
    local s = _scratchpads[i]
    if s.win:isMinimized() then
      _lastIndex = i
      show(s)
      return
    end
  end

  showAlert("No scratchpads minimized")
end

function M:bind(cfg)
  local utils   = dofile(_spoonPath .. "utils.lua")
  local actions = {
    ["scratchpad.add"]    = function() self:add() end,
    ["scratchpad.toggle"] = function() self:toggle() end,
  }
  for _, binding in ipairs(cfg.bindings) do
    if actions[binding.action] then
      utils.bind(cfg.hyper, binding.key, actions[binding.action])
    end
  end
end

return M