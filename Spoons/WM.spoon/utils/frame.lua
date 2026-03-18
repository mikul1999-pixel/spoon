local M = {}

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
