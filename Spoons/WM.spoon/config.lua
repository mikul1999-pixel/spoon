local M = {}

-- Core config options
M.hyper = {"ctrl","alt","cmd","shift"}  -- karabiner maps to caps lock
M.gaps = { inner = 3, outer = 0 }       -- gaps between windows

M.yabai = {
  path = "/opt/homebrew/bin/yabai",
}

M.workspaces = {
  backend = "yabai",
  count = 9,
  sendFollow = false,
  enableDirectSend = false,
  debug = false,
}

M.ui = {
  statusbar = {
    enabled = true,
    dynamicSpaces = true,
    pollInterval = 0.35,
    spacesRefreshInterval = 1.5,
    topInset = 34,
    tiledTopPadding = 6,
    reserveTopPadding = true,
    toast = {
      enabled = true,
      ttl = 1.2,
      maxChars = 34,
      dedupeWindow = 0.5,
      routeInfoAlerts = true,
    },
  },
}

M.behavior = {
  balanceAfterDirectionalMove = false,
  directionalFallback = true,
  directionalPolicy = {
    move = "smart",
    focus = "smart",
    swap = "smart",
  },
  autoFloatForGeometry = true,
  autoFloatOnMoveFailure = false,
  autoFloatOnDisplayMoveFailure = false,
  preferYabaiDisplayMove = true,
  followDisplayOnMove = true,
  retryCount = 2,
  placementHorizontalRatio = 0.5,
  placementVerticalBandRatio = 0.5,
  placementEdgeWarpPasses = 6,
}

M.policy = {
  defaults = {
    directional = {
      move = "smart",
      focus = "smart",
      swap = "smart",
    },
    autoFloat = {
      geometry = true,
      moveFailure = false,
      displayMoveFailure = false,
      swapFailure = false,
    },
    displayMove = {
      preferYabai = true,
      followDisplay = true,
      wrap = true,
      failureMode = "strict",
      tiledBehavior = "retile",
      floatingBehavior = "preserve_frame",
    },
    newWindow = {
      mode = "tile",
      insertion = "stack_end",
      focus = true,
    },
  },
  appRules = {
    { app = "Notes", mode = "float", focus = true },
  },
}

M.debug = {
  enabled = false,
  level = "info",
  maxEntries = 300,
}

M.scratchpad = {
  useWorkspaceTransport = false,
  workspace = 9,
  retrieveTarget = "current",
  followOnRetrieve = false,
  fallbackMinimize = true,
}

M.apps = {
  terminal = "Ghostty",
  editor   = "Code",
  browser  = "Firefox",
}

M.layouts = {
  dev = { -- 2 screen floating snapshot layout
    { order = 10, app = "editor", display = 1, space = 1, waitProfile = "editor", fallback = { x = 0.0, y = 0.0, w = 0.5, h = 1.0 } },
    { order = 20, app = "terminal", display = 1, space = 1, fallback = { x = 0.5, y = 0.0, w = 0.5, h = 1.0 } },
    { order = 30, app = "browser", display = 2, space = 1, fallback = { x = 0.0, y = 0.0, w = 1.0, h = 1.0 } },
  },
  laptop = { -- 1 screen floating snapshot layout
    { order = 10, app = "editor", display = 1, space = 1, waitProfile = "editor", fallback = { x = 0.0, y = 0.0, w = 0.5, h = 1.0 } },
    { order = 20, app = "terminal", display = 1, space = 1, fallback = { x = 0.5, y = 0.0, w = 0.5, h = 0.5 } },
    { order = 30, app = "browser", display = 1, space = 1, fallback = { x = 0.5, y = 0.5, w = 0.5, h = 0.5 } },
  },
}

M.layoutRuntime = {
  reuseExisting = true,
  launchIfMissing = true,
  createNewWhenRunning = false,
  settleMs = 90,
  waitProfiles = {
    default = { retries = 26, intervalMs = 120 },
    editor = { retries = 44, intervalMs = 150 },
  },
}

M.delays = {
  appLaunch  = 1.0,
  moveResize = 0.3,
  vscode     = 1.0,
}

-- single source of truth for all hotkeys
-- action strings are handled in their modules
M.bindings = {
  -- apps
  { key = "T", action = "app.terminal",       desc = "Terminal", ui = { section = "launch", order = 10 } },
  { key = "E", action = "app.editor",         desc = "Editor",   ui = { section = "launch", order = 20 } },
  { key = "B", action = "app.browser",        desc = "Browser",  ui = { section = "launch", order = 30 } },
  { key = "=", action = "app.newWindow",      desc = "New window", ui = { section = "launch", order = 40 } },
  { key = "return", action = "app.newTab",    desc = "New tab",  ui = { section = "launch", order = 50 } },
  -- window snapping
  { key = "H", action = "win.move.left",     desc = "Move left",  ui = { section = "window", order = 10, compact = "window.move", compactKey = "H/J/K/L", compactDesc = "Move window" } },
  { key = "J", action = "win.move.down",     desc = "Move down",  ui = { section = "window", order = 11, compact = "window.move", compactKey = "H/J/K/L", compactDesc = "Move window" } },
  { key = "K", action = "win.move.up",       desc = "Move up",    ui = { section = "window", order = 12, compact = "window.move", compactKey = "H/J/K/L", compactDesc = "Move window" } },
  { key = "L", action = "win.move.right",    desc = "Move right", ui = { section = "window", order = 13, compact = "window.move", compactKey = "H/J/K/L", compactDesc = "Move window" } },
  { key = "F", action = "win.maximize",      desc = "Fullscreen", ui = { section = "window", order = 20 } },
  { key = "C", action = "win.center",        desc = "Center",  ui = { section = "window", order = 30 } },
  { key = "G", action = "win.balance",       desc = "Balance", ui = { section = "window", order = 40 } },
  { key = "Z", action = "win.undo",          desc = "Undo",    ui = { section = "window", order = 50 } },
  { key = "space", action = "workspace.toggleFloat", desc = "Toggle float", ui = { section = "window", order = 60 } },
  -- window navigation
  { key = "N",   action = "win.nextMonitor", desc = "Next monitor", ui = { section = "display_focus", order = 10 } },
  { key = "P",   action = "win.prevMonitor", desc = "Prev monitor", ui = { section = "display_focus", order = 20 } },
  { key = "tab", action = "win.nextScreen",  desc = "Focus next screen", ui = { section = "display_focus", order = 30 } },
  { key = "`",   action = "win.cycleLocal",  desc = "Cycle local stack", ui = { section = "display_focus", order = 40 } },
  -- modes
  { key = "R", action = "win.resizeMode",      desc = "Resize mode",    ui = { section = "modes", order = 10 } },
  { key = "A", action = "workspace.focusMode", desc = "Focus mode",     ui = { section = "modes", order = 20 } },
  { key = "V", action = "workspace.swapMode",  desc = "Swap mode",      ui = { section = "modes", order = 30 } },
  { key = "W", action = "workspace.mode",      desc = "Workspace mode", ui = { section = "modes", order = 40 } },
  -- layouts
  { key = "D", action = "layout.dev",        desc = "Dev layout",    ui = { section = "layouts", order = 10 } },
  { key = "M", action = "layout.laptop",     desc = "Laptop layout", ui = { section = "layouts", order = 20 } },
  -- scratchpad
  { key = "[", action = "scratchpad.add",    desc = "Add to scratchpad", ui = { section = "scratchpad", order = 10 } },
  { key = "]", action = "scratchpad.toggle", desc = "Toggle scratchpad", ui = { section = "scratchpad", order = 20 } },
  -- help
  { key = "\\", action = "help.toggle",      desc = "Toggle help", ui = { section = "ui", order = 10 } },
}

for i = 1, M.workspaces.count do
  table.insert(M.bindings, {
    key = tostring(i),
    action = "workspace.focus." .. i,
    desc = "Workspace " .. i,
    ui = {
      section = "workspaces",
      order = 10 + i,
      compact = "workspace.focus.range",
      compactDesc = "Switch workspace",
    },
  })

  if M.workspaces.enableDirectSend then
    table.insert(M.bindings, {
      key = tostring(i),
      action = "workspace.send." .. i,
      desc = "Send to workspace " .. i,
      ui = {
        section = "workspaces",
        order = 40 + i,
      },
    })
  end
end

return M
