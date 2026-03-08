local M = {}

M.hyper = {"ctrl","alt","cmd","shift"} -- karabiner swap to caps lock

M.bindings = {
  { key = "t", name = "Terminal", desc="T"},
  { key = "e", name = "Editor",   desc="E"},
  { key = "b", name = "Browser",  desc="B"},
  { key = "l", name = "Layout",   desc="L"},
  { key = "w", name = "Window",   desc="W"},
}

-- App names for layouts
M.apps = {
  terminal = "Ghostty",
  editor   = "Code",     -- vscode
  browser  = "Firefox",
}

-- Timing delays for layouts, in seconds
M.delays = {
  appLaunch  = 1.0,   -- wait after launchOrFocus before running layout
  moveResize = 0.3,   -- wait between moveToScreen and setFrame
  vscode     = 1.0,   -- extra wait for vscode to open its window
}

return M