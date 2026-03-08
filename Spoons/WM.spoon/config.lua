local M = {}

M.hyper = {"ctrl","alt","cmd","shift"}  -- karabiner maps to caps lock

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
  { key = "T",      action = "app.terminal",  desc = "Terminal" },
  { key = "E",      action = "app.editor",    desc = "Editor" },
  { key = "B",      action = "app.browser",   desc = "Browser" },
  { key = "return", action = "app.newTab",    desc = "New tab" },
  -- window snapping
  { key = "H", action = "win.snapLeft",      desc = "Snap left" },
  { key = "L", action = "win.snapRight",     desc = "Snap right" },
  { key = "K", action = "win.snapTop",       desc = "Snap top" },
  { key = "J", action = "win.snapBottom",    desc = "Snap bottom" },
  { key = "F", action = "win.maximize",      desc = "Fullscreen" },
  { key = "C", action = "win.center",        desc = "Center" },
  { key = "Z", action = "win.undo",          desc = "Undo move" },
  -- window navigation
  { key = "N",   action = "win.nextMonitor", desc = "Next monitor" },
  { key = "P",   action = "win.prevMonitor", desc = "Prev monitor" },
  { key = "tab", action = "win.nextScreen",  desc = "Focus next screen" },
  { key = "`",   action = "win.cycleLocal",  desc = "Cycle windows" },
  -- modes
  { key = "R", action = "win.resizeMode",    desc = "Resize mode" }, -- exited through esc
  -- layouts
  { key = "D", action = "layout.dev",        desc = "Dev layout" },
  { key = "M", action = "layout.laptop",     desc = "Laptop layout" },
  -- help
  { key = "=", action = "help.toggle",       desc = "Help" },
}

return M