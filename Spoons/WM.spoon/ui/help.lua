local M = {}

-- UI help overlay for hyper keybindings
local _spoonPath
local _bind

function M:init(p)
  _spoonPath = p
  _bind = dofile(_spoonPath .. "utils/bind.lua")
end

local _canvas = nil
local _visible = false

local PAD     = 20
local ROW_H   = 22
local SEC_GAP = 10
local COL_W   = 260
local COLS    = 2
local CORNER  = 10
local FONT_SZ = 13
local HEAD_SZ = 12
local KEY_W   = 72

local COLORS = {
  bg      = { red=0.094, green=0.094, blue=0.145, alpha=0.96 },
  border  = { red=0.192, green=0.192, blue=0.267, alpha=1 },
  heading = { red=0.537, green=0.706, blue=0.980, alpha=1 },  -- blue
  key     = { red=0.976, green=0.886, blue=0.686, alpha=1 },  -- yellow
  desc    = { red=0.800, green=0.839, blue=0.957, alpha=1 },  -- text
  title   = { red=0.800, green=0.839, blue=0.957, alpha=1 },  -- same as desc, but brighter via weight
}

local SECTION_ORDER = { "app", "win", "workspace", "layout", "scratchpad", "help", "ui" }
local SECTION_LABELS = {
  app = "Apps",
  win = "Window",
  workspace = "Workspaces",
  layout = "Layouts",
  scratchpad = "Scratchpad",
  help = "Help",
  ui = "UI",
}

local function groupBindings(bindings)
  local groups = {}
  for _, b in ipairs(bindings) do
    local prefix = b.action:match("^([^.]+)%.")
    if prefix then
      groups[prefix] = groups[prefix] or {}
      table.insert(groups[prefix], b)
    end
  end
  return groups
end

local function buildRows(bindings)
  local groups = groupBindings(bindings)
  local rows = {}
  for _, section in ipairs(SECTION_ORDER) do
    if groups[section] then
      -- gap marker before every section, except first
      if #rows > 0 then
        table.insert(rows, { type = "gap" })
      end
      table.insert(rows, { type = "heading", label = (SECTION_LABELS[section] or section):upper() })
      for _, b in ipairs(groups[section]) do
        table.insert(rows, { type = "row", key = b.key:upper(), desc = b.desc })
      end
    end
  end
  return rows
end

local function createCanvas(bindings)
  local rows = buildRows(bindings)
  local half = math.ceil(#rows / COLS)

  -- measure actual height, rows + gaps
  local function colHeight(startIdx, count)
    local h = 0
    for i = startIdx, startIdx + count - 1 do
      local r = rows[i]
      if r then
        h = h + (r.type == "gap" and SEC_GAP or ROW_H)
      end
    end
    return h
  end

  local leftH  = colHeight(1, half)
  local rightH = colHeight(half + 1, #rows - half)
  local colH   = math.max(leftH, rightH)

  local TITLE_H = ROW_H + 14  -- title + separator
  local W = COLS * COL_W + PAD * 3
  local H = PAD + TITLE_H + PAD * 0.75 + colH + PAD

  local screen = hs.screen.primaryScreen():frame()
  local x = screen.x + (screen.w - W) / 2
  local y = screen.y + (screen.h - H) / 2

  local c = hs.canvas.new({ x = x, y = y, w = W, h = H })

  -- background + border
  c:appendElements({
    {
      type = "rectangle", action = "fill",
      fillColor = COLORS.bg,
      roundedRectRadii = { xRadius = CORNER, yRadius = CORNER },
    },
    {
      type = "rectangle", action = "stroke",
      strokeColor = COLORS.border, strokeWidth = 1,
      roundedRectRadii = { xRadius = CORNER, yRadius = CORNER },
    },
  })

  -- title
  c:appendElements({
    {
      type = "text",
      text = "WM hyper key bindings",
      textSize = HEAD_SZ + 2,
      textColor = COLORS.title,
      textAlignment = "center",
      frame = { x = 0, y = PAD, w = W, h = ROW_H },
      textFont = "Menlo-Bold",
    },
  })

  -- separator line under title
  local sepY = PAD + ROW_H + 6
  c:appendElements({
    {
      type = "segments",
      action = "stroke",
      strokeColor = COLORS.border,
      strokeWidth = 0.5,
      coordinates = {
        { x = PAD, y = sepY },
        { x = W - PAD, y = sepY },
      },
    },
  })

  -- render rows into two columns
  local contentY = sepY + 10
  local function renderCol(startIdx, count, colX)
    local ry = contentY
    for i = startIdx, startIdx + count - 1 do
      local row = rows[i]
      if not row then break end
      if row.type == "gap" then
        ry = ry + SEC_GAP
      elseif row.type == "heading" then
        c:appendElements({
          {
            type = "text",
            text = row.label,
            textSize = HEAD_SZ,
            textColor = COLORS.heading,
            textAlignment = "left",
            frame = { x = colX, y = ry, w = COL_W, h = ROW_H },
            textFont = "Menlo-Bold",
          },
        })
        ry = ry + ROW_H
      else
        c:appendElements({
          {
            type = "text",
            text = row.key,
            textSize = FONT_SZ,
            textColor = COLORS.key,
            textAlignment = "left",
            frame = { x = colX, y = ry, w = KEY_W, h = ROW_H },
            textFont = "Menlo-Bold",
          },
          {
            type = "text",
            text = row.desc,
            textSize = FONT_SZ,
            textColor = COLORS.desc,
            textAlignment = "left",
            frame = { x = colX + KEY_W, y = ry, w = COL_W - KEY_W, h = ROW_H },
            textFont = "Menlo",
          },
        })
        ry = ry + ROW_H
      end
    end
  end

  local leftColX  = PAD
  local rightColX = PAD * 2 + COL_W
  renderCol(1, half, leftColX)
  renderCol(half + 1, #rows - half, rightColX)

  return c
end

function M:toggle(bindings)
  if _visible then
    if _canvas then _canvas:hide(); _canvas:delete(); _canvas = nil end
    _visible = false
  else
    _canvas = createCanvas(bindings)
    _canvas:show()
    _visible = true
  end
end

function M:bind(cfg, commands)
  local actions = {
    ["help.toggle"] = function() self:toggle(cfg.bindings) end,
    ["ui.help.toggle"] = function() self:toggle(cfg.bindings) end,
  }

  for action, fn in pairs(actions) do
    commands:register(action, fn, { category = "help" })
  end

  for _, binding in ipairs(cfg.bindings) do
    if actions[binding.action] then
      _bind.bind(binding.mods or cfg.hyper, binding.key, function()
        commands:execute(binding.action)
      end)
    end
  end
end

function M:stop()
  if _canvas then _canvas:hide(); _canvas:delete(); _canvas = nil end
  _visible = false
end

return M
