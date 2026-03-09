local WM = {}
WM.__index = WM

WM.name    = "WM"
WM.version = "1.0"
WM.author  = "mikul"

local function scriptPath()
  local str = debug.getinfo(2, "S").source:sub(2)
  return str:match("(.*/)") or "./"
end
WM.spoonPath = scriptPath()

-- helper to load modules with self path
local function req(name)
  local m = dofile(WM.spoonPath .. name .. ".lua")
  if m.init then m:init(WM.spoonPath) end
  return m
end

function WM:init()
  self.config     = req("config")
  self.utils      = req("utils")
  self.apps       = req("apps")
  self.window     = req("window")
  self.layouts    = req("layouts")
  self.scratchpad = req("scratchpad")
  self.help       = req("help")
end

function WM:start()
  local cfg = self.config

  -- auto reload on .lua changes
  self._watcher = hs.pathwatcher.new(hs.configdir .. "/", function(files)
    for _, f in pairs(files) do
      if f:sub(-4) == ".lua" then hs.reload(); return end
    end
  end)
  self._watcher:start()

  self.apps:bind(cfg)
  self.window:bind(cfg)
  self.layouts:bind(cfg)
  self.scratchpad:bind(cfg)
  self.help:bind(cfg)

  hs.alert.show("WM loaded")
end

function WM:stop()
  if self._watcher then self._watcher:stop() end
  hs.hotkey.deleteAll()
end

-- standard Spoon hotkey wiring
function WM:bindHotkeys(mapping)
  self.config.hyper = mapping.hyper or self.config.hyper
end

return WM