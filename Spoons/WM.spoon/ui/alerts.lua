local M = {}

-- Alert system for toast messages like workspace changes, errors, warnings, ...
local _queue = {}
local _showing = false
local _canvas = nil
local _lastEnqueue = { msg = nil, kind = nil, at = 0 }
local _selfPath = debug.getinfo(1, "S").source:sub(2)
local _basePath = _selfPath:match("^(.*[/\\])")
local _canvasSafe = dofile(_basePath .. "canvas.lua")
local _shared = _G.__WM_ALERTS_SHARED or {}
_G.__WM_ALERTS_SHARED = _shared

local function toastConfig()
  local cfg = _shared.config or {}
  local ui = cfg.ui and cfg.ui.statusbar or {}
  local toast = ui.toast or {}
  return {
    enabled = toast.enabled ~= false,
    routeInfo = toast.routeInfoAlerts ~= false,
    ttl = tonumber(toast.ttl) or 1.2,
  }
end

local PALETTE = {
  info = {
    bg     = { red=0.12, green=0.12, blue=0.18, alpha=0.93 },
    border = { red=0.54, green=0.71, blue=0.98, alpha=1 },   -- blue
    text   = { red=0.80, green=0.84, blue=0.96, alpha=1 },   -- text
  },
  warn = {
    bg     = { red=0.18, green=0.15, blue=0.05, alpha=0.95 },
    border = { red=0.98, green=0.89, blue=0.69, alpha=1 },   -- yellow
    text   = { red=0.98, green=0.95, blue=0.86, alpha=1 },
  },
  error = {
    bg     = { red=0.22, green=0.05, blue=0.07, alpha=0.95 },
    border = { red=0.95, green=0.55, blue=0.66, alpha=1 },   -- red
    text   = { red=0.99, green=0.91, blue=0.93, alpha=1 },
  },
}

local function textSize(msg)
  local ok, sz = pcall(hs.drawing.getTextDrawingSize, msg, {
    font = "Menlo",
    size = 13,
  })
  if ok and sz and sz.w and sz.h then
    return sz
  end
  return { w = math.max(120, #tostring(msg) * 7), h = 20 }
end

local function now()
  if hs and hs.timer and hs.timer.secondsSinceEpoch then
    return hs.timer.secondsSinceEpoch()
  end
  return os.time()
end

local function destroyCanvas()
  if _canvas then
    _canvas:hide()
    _canvas:delete()
    _canvas = nil
  end
end

local function showNext()
  if #_queue == 0 then
    _showing = false
    return
  end

  _showing = true
  local item = table.remove(_queue, 1)
  local kind = item.kind or "info"
  local style = PALETTE[kind] or PALETTE.info
  local msg = tostring(item.msg or "")
  local dur = tonumber(item.duration) or 0.9

  destroyCanvas()

  local sz = textSize(msg)
  local padX, padY = 18, 12
  local w = math.min(720, math.max(220, sz.w + padX * 2))
  local h = math.max(40, sz.h + padY * 2)

  local screen = hs.screen.primaryScreen():frame()
  local frame = {
    x = screen.x + (screen.w - w) / 2,
    y = screen.y + (screen.h - h) / 2 - 48,
    w = w,
    h = h,
  }

  _canvas = hs.canvas.new(frame)
  _canvas:level(hs.canvas.windowLevels.floating)
  _canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)

  _canvasSafe.append(_canvas, {
    {
      type = "rectangle",
      action = "fill",
      fillColor = style.bg,
      roundedRectRadii = { xRadius = 10, yRadius = 10 },
    },
    {
      type = "rectangle",
      action = "stroke",
      strokeColor = style.border,
      strokeWidth = 1.5,
      roundedRectRadii = { xRadius = 10, yRadius = 10 },
    },
    {
      type = "text",
      text = msg,
      textFont = "Menlo",
      textSize = 13,
      textColor = style.text,
      textAlignment = "center",
      frame = { x = padX, y = padY - 1 + 4, w = w - padX * 2, h = h - padY * 2 },
    },
  }, "alerts.showNext")

  _canvas:show()
  hs.timer.doAfter(dur, function()
    destroyCanvas()
    showNext()
  end)
end

local function enqueue(msg, duration, kind)
  local text = tostring(msg or "")
  local t = now()
  if _lastEnqueue.msg == text and _lastEnqueue.kind == kind and (t - (_lastEnqueue.at or 0)) < 0.45 then
    return
  end
  _lastEnqueue.msg = text
  _lastEnqueue.kind = kind
  _lastEnqueue.at = t

  table.insert(_queue, {
    msg = text,
    duration = duration,
    kind = kind,
  })
  if not _showing then showNext() end
end

function M.show(msg, duration)
  local cfg = toastConfig()
  local statusbar = _shared.statusbar
  if cfg.enabled and cfg.routeInfo and statusbar and statusbar.notify then
    local ok = statusbar:notify(msg, { ttl = duration or cfg.ttl, kind = "info" })
    if ok then return end
  end

  enqueue(msg, duration or 0.85, "info")
end

function M.warn(msg)
  enqueue(msg, 1.2, "warn")
end

function M.error(msg)
  enqueue(msg, 1.4, "error")
end

function M:setStatusbar(statusbar, config)
  _shared.statusbar = statusbar
  if config then _shared.config = config end
end

return M
