local M = {}
local _spoonPath
function M:init(p) _spoonPath = p end

local _canvas = nil
local _visible = false

-- layout constants
local PAD     = 24
local ROW_H   = 28
local COL_W   = 260
local COLS    = 2
local CORNER  = 10
local FONT_SZ = 14
local HEAD_SZ = 13

local COLORS = {
  bg      = { red=0.08, green=0.08, blue=0.10, alpha=0.93 },
  border  = { red=0.30, green=0.30, blue=0.35, alpha=0.80 },
  heading = { red=0.45, green=0.65, blue=1.00, alpha=1 },
  key     = { red=0.95, green=0.75, blue=0.30, alpha=1 },
  desc    = { red=0.88, green=0.88, blue=0.90, alpha=1 },
  title   = { red=1,    green=1,    blue=1,    alpha=1 },
}

-- group bindings by action prefix for section headers
local SECTION_ORDER = { "app", "win", "layout", "scratchpad","help" }
local SECTION_LABELS = { app="Apps", win="Window", layout="Layouts", scratchpad="Scratchpad", help="Help" }

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
  local rows = {}  -- { type, label, key, desc }
  for _, section in ipairs(SECTION_ORDER) do
    if groups[section] then
      table.insert(rows, { type="heading", label=SECTION_LABELS[section] })
      for _, b in ipairs(groups[section]) do
        table.insert(rows, { type="row", key=b.key:upper(), desc=b.desc })
      end
    end
  end
  return rows
end

local function createCanvas(bindings)
  local rows  = buildRows(bindings)
  local half  = math.ceil(#rows / COLS)

  local colH  = half * ROW_H + PAD
  local W     = COLS * COL_W + PAD * 3
  local H     = colH + PAD * 3 + ROW_H  -- title row + content + padding

  local screen = hs.screen.primaryScreen():frame()
  local x = screen.x + (screen.w - W) / 2
  local y = screen.y + (screen.h - H) / 2

  local c = hs.canvas.new({ x=x, y=y, w=W, h=H })

  -- background + border
  c:appendElements({
    { type="rectangle", action="fill",   fillColor=COLORS.bg,
      roundedRectRadii={ xRadius=CORNER, yRadius=CORNER } },
    { type="rectangle", action="stroke", strokeColor=COLORS.border, strokeWidth=1,
      roundedRectRadii={ xRadius=CORNER, yRadius=CORNER } },
  })

  -- title
  c:appendElements({
    { type="text", text="WM hyper key bindings", textSize=HEAD_SZ+1,
      textColor=COLORS.title, textAlignment="center",
      frame={ x=0, y=PAD, w=W, h=ROW_H },
      textFont="Menlo-Bold" },
  })

  local contentY = PAD + ROW_H + PAD * 0.5

  -- render rows into two columns
  for i, row in ipairs(rows) do
    local col  = i <= half and 0 or 1
    local rIdx = i <= half and i or (i - half)
    local rx   = PAD + col * (COL_W + PAD)
    local ry   = contentY + (rIdx - 1) * ROW_H

    if row.type == "heading" then
      c:appendElements({
        { type="text", text=row.label, textSize=HEAD_SZ,
          textColor=COLORS.heading, textAlignment="left",
          frame={ x=rx, y=ry, w=COL_W, h=ROW_H },
          textFont="Menlo-Bold" },
      })
    else
      -- key badge
      c:appendElements({
        { type="text", text=row.key, textSize=FONT_SZ,
          textColor=COLORS.key, textAlignment="left",
          frame={ x=rx, y=ry, w=50, h=ROW_H },
          textFont="Menlo-Bold" },
        { type="text", text=row.desc, textSize=FONT_SZ,
          textColor=COLORS.desc, textAlignment="left",
          frame={ x=rx+54, y=ry, w=COL_W-54, h=ROW_H },
          textFont="Menlo" },
      })
    end
  end

  return c
end

function M:toggle(bindings)
  if _visible then
    if _canvas then _canvas:hide(); _canvas:delete(); _canvas = nil end
    _visible = false
  else
    _canvas  = createCanvas(bindings)
    _canvas:show()
    _visible = true
  end
end

function M:bind(cfg)
  local utils = dofile(_spoonPath .. "utils.lua")
  local h, b  = cfg.hyper, cfg.bindings

  for _, binding in ipairs(b) do
    if binding.action == "help.toggle" then
      utils.bind(h, binding.key, function() self:toggle(b) end)
    end
  end
end

return M