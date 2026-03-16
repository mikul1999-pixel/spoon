local M = {}

-- Helpers to find a target window given a direction
function M.directionalTarget(win, dir, opts)
  if not win then return nil end

  opts = opts or {}
  local sameScreenOnly = opts.sameScreen ~= false
  local includeMinimized = opts.includeMinimized == true

  local wf = win:frame()
  local wcx = wf.x + wf.w / 2
  local wcy = wf.y + wf.h / 2
  local screen = win:screen()

  local candidates = hs.fnutils.filter(hs.window.orderedWindows(), function(candidate)
    if candidate:id() == win:id() then return false end
    if not candidate:isVisible() then return false end
    if not includeMinimized and candidate:isMinimized() then return false end
    if sameScreenOnly and candidate:screen() ~= screen then return false end
    return true
  end)

  local bestWindow = nil
  local bestScore = nil

  for _, candidate in ipairs(candidates) do
    local cf = candidate:frame()
    local ccx = cf.x + cf.w / 2
    local ccy = cf.y + cf.h / 2
    local dx = ccx - wcx
    local dy = ccy - wcy

    local primary = nil
    local secondary = nil
    if dir == "left" and dx < 0 then
      primary = -dx
      secondary = math.abs(dy)
    elseif dir == "right" and dx > 0 then
      primary = dx
      secondary = math.abs(dy)
    elseif dir == "up" and dy < 0 then
      primary = -dy
      secondary = math.abs(dx)
    elseif dir == "down" and dy > 0 then
      primary = dy
      secondary = math.abs(dx)
    end

    if primary then
      local score = primary + secondary * 0.35
      if not bestScore or score < bestScore then
        bestScore = score
        bestWindow = candidate
      end
    end
  end

  return bestWindow
end

return M
