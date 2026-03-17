local M = {}

-- Top status bar with workspace tabs and mode indicator
local _spoonPath
local _canvas
local _timer
local _state
local _cfg
local _logger
local _shell
local _canvasSafe
local _visible = true
local _workspaceCount = 9
local _lastSpacesQueryAt = 0
local _toastCanvas
local _toastTimer
local _toast = {
  msg = nil,
  kind = "info",
  expiresAt = 0,
  lastMsg = nil,
  lastAt = 0,
}

local _last = {
  workspace = nil,
  mode = nil,
  screenId = nil,
  workspaceCount = nil,
}

local STYLE = {
  height = 30,
  padX = 6,
  tabW = 22,
  tabGap = 5,
  modeW = 106,
  marginX = 10,
  marginY = 5,
  corner = 4,

  bg             = { red=0.12, green=0.12, blue=0.18, alpha=0.85 },
  border         = { red=0.19, green=0.19, blue=0.27, alpha=1 },
  inactiveTabText= { red=0.42, green=0.44, blue=0.53, alpha=1 },
  activeTabText  = { red=0.80, green=0.84, blue=0.96, alpha=1 },
  inactiveTabBg  = { red = 0, green = 0, blue = 0, alpha = 0  },
  activeTabBg    = { red = 0, green = 0, blue = 0, alpha = 0  },
  modeText       = { red=0.12, green=0.12, blue=0.18, alpha=1 },
}

local TOAST_STYLE = {
  info = {
    bg     = { red=0.106, green=0.118, blue=0.188, alpha=0.88 },
    border = { red=0.431, green=0.561, blue=0.749, alpha=1 },
    text   = { red=0.639, green=0.722, blue=0.847, alpha=1 },
  },
  warn = {
    bg     = { red=0.149, green=0.118, blue=0.055, alpha=0.90 },
    border = { red=0.769, green=0.659, blue=0.353, alpha=1 },
    text   = { red=0.831, green=0.722, blue=0.478, alpha=1 },
  },
  error = {
    bg     = { red=0.173, green=0.071, blue=0.094, alpha=0.90 },
    border = { red=0.710, green=0.376, blue=0.439, alpha=1 },
    text   = { red=0.769, green=0.490, blue=0.541, alpha=1 },
  },
}

local MODE_COLORS = {
  normal    = { red=0.54, green=0.71, blue=0.98, alpha=1 },  -- blue
  resize    = { red=0.95, green=0.55, blue=0.66, alpha=1 },  -- red
  workspace = { red=0.79, green=0.65, blue=0.97, alpha=1 },  -- mauve
  focus     = { red=0.54, green=0.86, blue=0.92, alpha=1 },  -- sky
  swap      = { red=0.96, green=0.76, blue=0.89, alpha=1 },  -- pink
  send      = { red=0.65, green=0.89, blue=0.63, alpha=1 },  -- green
}

function M:init(p)
  _spoonPath = p
  _shell = dofile(_spoonPath .. "utils/shell.lua")
  _canvasSafe = dofile(_spoonPath .. "ui/canvas.lua")
end

local function log(level, event, message, data)
  if _logger and _logger[level] then
    _logger[level](_logger, event, message, data)
  end
end

local function modeLabel(mode)
  local map = {
    normal = "NORMAL",
    resize = "RESIZE",
    workspace = "WORKSPACE",
    focus = "FOCUS",
    swap = "SWAP",
    send = "SEND",
  }
  return map[mode] or string.upper(tostring(mode or "normal"))
end

local function now()
  if hs and hs.timer and hs.timer.secondsSinceEpoch then
    return hs.timer.secondsSinceEpoch()
  end
  return os.time()
end

local function toastConfig()
  local ui = (_cfg and _cfg.ui and _cfg.ui.statusbar) or {}
  local toast = ui.toast or {}
  return {
    enabled = toast.enabled ~= false,
    ttl = tonumber(toast.ttl) or 1.2,
    maxChars = math.max(8, tonumber(toast.maxChars) or 34),
    dedupeWindow = math.max(0, tonumber(toast.dedupeWindow) or 0.5),
  }
end

local function activeToastText()
  local cfg = toastConfig()
  if not cfg.enabled then return nil end
  if not _toast.msg or _toast.msg == "" then return nil end
  if now() >= (_toast.expiresAt or 0) then
    _toast.msg = nil
    return nil
  end
  return _toast.msg
end

local function toastTextSize(msg)
  local ok, sz = pcall(hs.drawing.getTextDrawingSize, tostring(msg or ""), {
    font = "Menlo",
    size = 11,
  })
  if ok and sz and sz.w and sz.h then
    return sz
  end
  return { w = math.max(80, #tostring(msg or "") * 6), h = 16 }
end

local function destroyToastCanvas()
  if _toastTimer then
    _toastTimer:stop()
    _toastTimer = nil
  end
  if _toastCanvas then
    _toastCanvas:hide()
    _toastCanvas:delete()
    _toastCanvas = nil
  end
end

local function renderToast()
  if not _visible or not _canvas then
    destroyToastCanvas()
    return
  end

  local msg = activeToastText()
  if not msg then
    destroyToastCanvas()
    return
  end

  local kind = _toast.kind or "info"
  local palette = TOAST_STYLE[kind] or TOAST_STYLE.info
  local bar = _canvas:frame()
  local sz = toastTextSize(msg)
  local padX, padY = 10, 6
  local w = math.min(300, math.max(120, sz.w + padX * 2))
  local h = 24
  local frame = {
    x = bar.x + bar.w + 8,
    y = bar.y + math.floor((bar.h - h) / 2),
    w = w,
    h = h,
  }

  if not _toastCanvas then
    _toastCanvas = hs.canvas.new(frame)
    _toastCanvas:level(hs.canvas.windowLevels.status)
    _toastCanvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
  else
    _toastCanvas:frame(frame)
  end

  _canvasSafe.replace(_toastCanvas, {
    {
      type = "rectangle",
      action = "fill",
      fillColor = palette.bg,
      roundedRectRadii = { xRadius = 4, yRadius = 4 },
    },
    {
      type = "rectangle",
      action = "stroke",
      strokeColor = palette.border,
      strokeWidth = 1.3,
      roundedRectRadii = { xRadius = 4, yRadius = 4 },
    },
    {
      type = "text",
      text = msg,
      textFont = "Menlo",
      textSize = 11,
      textColor = palette.text,
      textAlignment = "center",
      frame = { x = padX, y = padY + 1, w = w - padX * 2, h = h - padY * 2 },
    },
  }, "statusbar.toast")

  _toastCanvas:show()

  if _toastTimer then _toastTimer:stop() end
  local remaining = (_toast.expiresAt or 0) - now()
  _toastTimer = hs.timer.doAfter(math.max(0.05, remaining), function()
    _toast.msg = nil
    destroyToastCanvas()
  end)
end

local function shouldQuerySpaces()
  local ui = (_cfg and _cfg.ui and _cfg.ui.statusbar) or {}
  local every = tonumber(ui.spacesRefreshInterval) or 1.5
  return (now() - _lastSpacesQueryAt) >= every
end

local function updateWorkspaceCountFromYabai()
  local ui = (_cfg and _cfg.ui and _cfg.ui.statusbar) or {}
  if ui.dynamicSpaces == false then
    _workspaceCount = (_cfg and _cfg.workspaces and _cfg.workspaces.count) or 9
    return
  end
  if not _shell then return end
  if not shouldQuerySpaces() then return end

  _lastSpacesQueryAt = now()
  local path = (_cfg and _cfg.yabai and _cfg.yabai.path) or "/opt/homebrew/bin/yabai"
  local ok, out = _shell.exec(path, { "-m", "query", "--spaces" })
  if not ok then return end

  local decoded = hs.json.decode(out)
  if type(decoded) ~= "table" then return end

  local count = #decoded
  if count >= 1 and count <= 20 then
    _workspaceCount = count
  end
end

local function canvasFrame()
  local screen = hs.screen.primaryScreen()
  if not screen then return nil, nil end

  local f = screen:frame()
  local tabsW = _workspaceCount * STYLE.tabW + math.max(0, _workspaceCount - 1) * STYLE.tabGap
  local width = STYLE.padX * 3 + tabsW + STYLE.modeW

  return {
    x = f.x + STYLE.marginX,
    y = f.y + STYLE.marginY,
    w = width,
    h = STYLE.height,
  }, screen:id()
end

local function render(workspace, mode)
  if not _canvas then return end

  local tabsW = _workspaceCount * STYLE.tabW + math.max(0, _workspaceCount - 1) * STYLE.tabGap
  local cW = _canvas:frame().w
  local cH = _canvas:frame().h
  local modeBg = MODE_COLORS[mode] or MODE_COLORS.normal

  _canvasSafe.replace(_canvas, {
    {
      type = "rectangle",
      action = "fill",
      fillColor = STYLE.bg,
      roundedRectRadii = { xRadius = STYLE.corner, yRadius = STYLE.corner },
    },
    {
      type = "rectangle",
      action = "stroke",
      strokeColor = STYLE.border,
      strokeWidth = 1,
      roundedRectRadii = { xRadius = STYLE.corner, yRadius = STYLE.corner },
    },
  }, "statusbar.base")

  local y = (cH - 20) / 2 + 1

  _canvasSafe.append(_canvas, {
    {
      type = "rectangle",
      action = "fill",
      fillColor = modeBg,
      frame = { x = STYLE.padX, y = y, w = STYLE.modeW, h = 18 },
    },
    {
      type = "text",
      text = modeLabel(mode),
      textFont = "Menlo-Bold",
      textSize = 12,
      textColor = STYLE.modeText,
      textAlignment = "center",
      frame = { x = STYLE.padX, y = y + 2, w = STYLE.modeW, h = 16 },
    },
  }, "statusbar.mode")

  local x = STYLE.padX * 2 + STYLE.modeW
  for i = 1, _workspaceCount do
    local active = i == workspace
    _canvasSafe.append(_canvas, {
      {
        type = "rectangle",
        action = "fill",
        fillColor = active and STYLE.activeTabBg or STYLE.inactiveTabBg,
        frame = { x = x, y = y, w = STYLE.tabW, h = 18 },
      },
      {
        type = "text",
        text = tostring(i),
        textFont = "Menlo",
        textSize = 11,
        textColor = active and STYLE.activeTabText or STYLE.inactiveTabText,
        textAlignment = "center",
        frame = { x = x, y = y + 2, w = STYLE.tabW, h = 14 },
      },
    }, "statusbar.tabs")
    x = x + STYLE.tabW + STYLE.tabGap
  end
end

local function reconcileAndRender(force)
  if not _visible or not _state then return end

  updateWorkspaceCountFromYabai()
  local frame, screenId = canvasFrame()
  if not frame then return end

  if not _canvas then
    _canvas = hs.canvas.new(frame)
    _canvas:level(hs.canvas.windowLevels.status)
    _canvas:behavior(hs.canvas.windowBehaviors.canJoinAllSpaces)
    _canvas:show()
  elseif force or _last.screenId ~= screenId then
    _canvas:frame(frame)
  end

  local workspace = _state:currentWorkspace() or 1
  local mode = _state:mode() or "normal"

  if workspace > _workspaceCount then workspace = _workspaceCount end
  if workspace < 1 then workspace = 1 end

  if not force
    and _last.workspace == workspace
    and _last.mode == mode
    and _last.screenId == screenId
    and _last.workspaceCount == _workspaceCount then
    renderToast()
    return
  end

  _last.workspace = workspace
  _last.mode = mode
  _last.screenId = screenId
  _last.workspaceCount = _workspaceCount
  render(workspace, mode)
  renderToast()
end

function M:start(ctx)
  _cfg = ctx and ctx.config or _cfg
  _state = ctx and ctx.state or _state
  _logger = ctx and ctx.logger or _logger
  _visible = true
  _workspaceCount = (_cfg and _cfg.workspaces and _cfg.workspaces.count) or 9
  _toast.msg = nil
  _toast.kind = "info"
  _toast.expiresAt = 0
  _toast.lastMsg = nil
  _toast.lastAt = 0
  destroyToastCanvas()

  reconcileAndRender(true)

  if _timer then _timer:stop() end
  local every = (_cfg and _cfg.ui and _cfg.ui.statusbar and _cfg.ui.statusbar.pollInterval) or 0.35
  _timer = hs.timer.doEvery(every, function()
    reconcileAndRender(false)
  end)

  log("info", "ui.statusbar", "status bar started", { workspaces = _workspaceCount })
end

function M:refresh()
  reconcileAndRender(true)
end

function M:notify(msg, opts)
  local cfg = toastConfig()
  if not cfg.enabled then return false end
  msg = tostring(msg or "")
  msg = msg:gsub("%s+", " "):gsub("^%s+", ""):gsub("%s+$", "")
  if msg == "" then return false end

  if #msg > cfg.maxChars then
    msg = msg:sub(1, math.max(1, cfg.maxChars - 1)) .. "..."
  end

  local t = now()
  if _toast.lastMsg == msg and (t - (_toast.lastAt or 0)) < cfg.dedupeWindow then
    return true
  end

  local ttl = (opts and tonumber(opts.ttl)) or cfg.ttl
  _toast.msg = msg
  _toast.kind = (opts and opts.kind) or "info"
  _toast.expiresAt = t + math.max(0.2, ttl)
  _toast.lastMsg = msg
  _toast.lastAt = t
  renderToast()
  return true
end

function M:toggle()
  _visible = not _visible
  if _visible then
    reconcileAndRender(true)
    if _canvas then _canvas:show() end
    renderToast()
  else
    if _canvas then _canvas:hide() end
    if _toastCanvas then _toastCanvas:hide() end
  end
  return _visible
end

function M:stop()
  if _timer then _timer:stop(); _timer = nil end
  destroyToastCanvas()
  if _canvas then _canvas:hide(); _canvas:delete(); _canvas = nil end
end

return M
