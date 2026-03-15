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
  self.logger     = req("core/logger")
  self.commands   = req("core/commands")
  self.state      = req("core/state")
  self.modes      = req("core/modes")
  self.backend    = req("core/backend")
  self.apps       = req("features/apps")
  self.window     = req("features/window")
  self.workspaces = req("features/workspaces")
  self.layouts    = req("features/layouts")
  self.scratchpad = req("features/scratchpad")
  self.help       = req("features/help")
end

function WM:start()
  local cfg = self.config
  self.logger:configure(cfg)

  self.commands:reset()
  self.state:reset()
  self.modes:reset()
  self.backend:init({
    spoonPath = self.spoonPath,
    config = cfg,
    state = self.state,
    logger = self.logger,
  })

  self.commands:register("wm.backendHealth", function()
    print(hs.inspect(self.backend:health()))
  end, { category = "wm" })

  self.commands:register("wm.debugToggle", function()
    local enabled = self.logger:toggleDebug()
    hs.alert.show("WM debug " .. (enabled and "on" or "off"))
  end, { category = "wm" })

  self.commands:register("wm.debugLast", function(args)
    local n = args and args.count or 25
    print(hs.inspect(self.logger:last(n)))
  end, { category = "wm" })

  -- auto reload on .lua changes
  self._watcher = hs.pathwatcher.new(hs.configdir .. "/", function(files)
    for _, f in pairs(files) do
      if f:sub(-4) == ".lua" then hs.reload(); return end
    end
  end)
  self._watcher:start()

  self.apps:bind(cfg, self.commands)
  self.window:bind(cfg, self.commands, self.backend, self.logger, self.modes)
  self.workspaces:bind(cfg, self.commands, self.state, self.backend, self.logger, self.modes)
  self.layouts:bind(cfg, self.commands)
  self.scratchpad:bind(cfg, self.commands, self.state, self.backend, self.logger)
  self.help:bind(cfg, self.commands)

  self.logger:info("wm.start", "WM started", { backend = self.backend:name() })
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
