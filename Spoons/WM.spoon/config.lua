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
  useWorkspaceTransport = true,
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
  dev = { -- 2 screen layout for pc development
    { app="browser",  screen=2, x=0,   y=0,   w=1,   h=1 },
    { app="terminal", screen=1, x=0.5, y=0,   w=0.5, h=1 },
    { app="editor",   screen=1, x=0,   y=0,   w=0.5, h=1 },
  },
  laptop = { -- 1 screen layout for my laptop
    { app="browser",  screen=1, x=0.5, y=0.5, w=0.5, h=0.5 },
    { app="terminal", screen=1, x=0.5, y=0,   w=0.5, h=0.5 },
    { app="editor",   screen=1, x=0,   y=0,   w=0.5, h=1   },
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
  { key = "T", action = "app.terminal",       desc = "Terminal" },
  { key = "E", action = "app.editor",         desc = "Editor" },
  { key = "B", action = "app.browser",        desc = "Browser" },
  { key = "return", action = "app.newTab",    desc = "New tab" },
  -- window snapping
  { key = "H", action = "win.move.left",     desc = "Move left" },
  { key = "J", action = "win.move.down",     desc = "Move down" },
  { key = "K", action = "win.move.up",       desc = "Move up" },
  { key = "L", action = "win.move.right",    desc = "Move right" },
  { key = "F", action = "win.maximize",      desc = "Fullscreen" },
  { key = "C", action = "win.center",        desc = "Center" },
  { key = "Z", action = "win.undo",          desc = "Undo move" },
  { key = "G", action = "win.balance",       desc = "Snap to balanced grid" },
  -- window navigation
  { key = "N",   action = "win.nextMonitor", desc = "Next monitor" },
  { key = "P",   action = "win.prevMonitor", desc = "Prev monitor" },
  { key = "tab", action = "win.nextScreen",  desc = "Focus next screen" },
  { key = "`",   action = "win.cycleLocal",  desc = "Cycle windows" },
  -- modes
  { key = "R", action = "win.resizeMode",    desc = "Resize mode" },
  { key = "W", action = "workspace.mode",    desc = "Workspace mode" },
  { key = "S", action = "workspace.sendMode", desc = "Workspace send mode" },
  { key = "A", action = "workspace.focusMode", desc = "Focus mode" },
  { key = "V", action = "workspace.swapMode", desc = "Swap mode" },
  { key = "space", action = "workspace.toggleFloat", desc = "Toggle float" },
  -- layouts
  { key = "D", action = "layout.dev",        desc = "Dev layout" },
  { key = "M", action = "layout.laptop",     desc = "Laptop layout" },
  -- scratchpad
  { key = "[", action = "scratchpad.add",    desc = "Add to scratchpad" },
  { key = "]", action = "scratchpad.toggle", desc = "Toggle scratchpad" },
  -- help
  { key = "\\", action = "help.toggle",      desc = "Help" },
}

for i = 1, M.workspaces.count do
  table.insert(M.bindings, {
    key = tostring(i),
    action = "workspace.focus." .. i,
    desc = "Workspace " .. i,
  })

  if M.workspaces.enableDirectSend then
    table.insert(M.bindings, {
      key = tostring(i),
      action = "workspace.send." .. i,
      desc = "Send to workspace " .. i,
    })
  end
end

return M
