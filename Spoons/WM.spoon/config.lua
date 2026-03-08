local M = {}

M.hyper = {"ctrl","alt","cmd","shift"}  -- karabiner maps to caps lock

M.apps = {
  terminal = "Ghostty",
  editor   = "Code",
  browser  = "Firefox",
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
  { key = "T", action = "app.terminal",      desc = "Terminal" },
  { key = "E", action = "app.editor",        desc = "Editor" },
  { key = "B", action = "app.browser",       desc = "Browser" },
  -- window snapping
  { key = "H", action = "win.snapLeft",      desc = "Snap left" },
  { key = "L", action = "win.snapRight",     desc = "Snap right" },
  { key = "K", action = "win.snapTop",       desc = "Snap top" },
  { key = "J", action = "win.snapBottom",    desc = "Snap bottom" },
  { key = "F", action = "win.maximize",      desc = "Maximize" },
  { key = "C", action = "win.center",        desc = "Center" },
  { key = "Z", action = "win.undo",          desc = "Undo move" },
  -- window navigation
  { key = "N",   action = "win.nextMonitor", desc = "Next monitor" },
  { key = "P",   action = "win.prevMonitor", desc = "Prev monitor" },
  { key = "tab", action = "win.nextScreen",  desc = "Focus next screen" },
  { key = "`",   action = "win.cycleLocal",  desc = "Cycle screen wins" },
  -- modes
  { key = "R", action = "win.resizeMode",    desc = "Resize mode" }, -- exited through esc
  -- layouts
  { key = "D", action = "layout.dev",        desc = "Dev layout" },
  -- help
  { key = "=", action = "help.toggle",       desc = "Help" },
}

return M