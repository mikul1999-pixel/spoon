local M = {}

function M.show(msg, duration)
  hs.alert.show(msg, { textSize = 16 }, duration or 0.6)
end

function M.warn(msg)
  M.show(msg, 1.0)
end

return M
