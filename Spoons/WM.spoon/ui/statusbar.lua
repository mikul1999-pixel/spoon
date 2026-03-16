local M = {}

-- Top status bar with workspace tabs and mode indicator
local _spoonPath
local _canvas
local _timer
local _state
local _cfg
local _logger
local _shell
local _visible = true
local _workspaceCount = 9
local _lastSpacesQueryAt = 0

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

  _canvas:replaceElements({
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
  })

  local y = (cH - 20) / 2 + 1

  _canvas:appendElements({
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
  })

  local x = STYLE.padX * 2 + STYLE.modeW
  for i = 1, _workspaceCount do
    local active = i == workspace
    _canvas:appendElements({
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
    })
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
    return
  end

  _last.workspace = workspace
  _last.mode = mode
  _last.screenId = screenId
  _last.workspaceCount = _workspaceCount
  render(workspace, mode)
end

function M:start(ctx)
  _cfg = ctx and ctx.config or _cfg
  _state = ctx and ctx.state or _state
  _logger = ctx and ctx.logger or _logger
  _visible = true
  _workspaceCount = (_cfg and _cfg.workspaces and _cfg.workspaces.count) or 9

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

function M:toggle()
  _visible = not _visible
  if _visible then
    reconcileAndRender(true)
    if _canvas then _canvas:show() end
  else
    if _canvas then _canvas:hide() end
  end
  return _visible
end

function M:stop()
  if _timer then _timer:stop(); _timer = nil end
  if _canvas then _canvas:hide(); _canvas:delete(); _canvas = nil end
end

return M
