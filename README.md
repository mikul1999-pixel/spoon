# hammerspoon

Personal macOS automation config

## Spoons

### WM - Window Manager

Custom window manager built with Hammerspoon + yabai.

Config: `Spoons/WM.spoon/config.lua`

### Prerequisites

- [Karabiner-Elements](https://karabiner-elements.pqrs.org/) maps caps lock -> hyper (`ctrl+alt+cmd+shift`)
- [Hammerspoon](https://www.hammerspoon.org/) runs hotkeys, UI, layouts, and policy/fallback orchestration
- [yabai](https://github.com/koekeishiya/yabai) executes tiled window/workspace commands

### Keybindings

| Key | Action |
|---|---|
| `hyper+T` | Terminal |
| `hyper+E` | Editor |
| `hyper+B` | Browser |
| `hyper+=` | New window (focused app) |
| `hyper+return` | New tab (focused app) |
| `hyper+H/J/K/L` | Move window |
| `hyper+F` | Fullscreen |
| `hyper+C` | Center |
| `hyper+G` | Balance workspace |
| `hyper+Z` | Undo floating move |
| `hyper+space` | Toggle float |
| `hyper+N/P` | Move window next/prev monitor |
| `hyper+tab` | Focus next screen |
| ``hyper+` `` | Cycle local stack (on same screen) |
| `hyper+1..9` | Focus workspace |
| `hyper+R` | Resize mode |
| `hyper+A` | Focus mode |
| `hyper+V` | Swap mode |
| `hyper+W` | Workspace mode |
| `hyper+D` | Dev layout |
| `hyper+M` | Laptop layout |
| `hyper+[` | Add to scratchpad |
| `hyper+]` | Toggle scratchpad |
| `hyper+\` | Toggle help |

### Behavior Notes

- Hammerspoon acts as the control/policy layer (modes, intent, fallbacks, UI/logging), and yabai is the execution backend for tiled window ops.
- A few actions stay fully in Hammerspoon, but its main role is orchestration: decide what should happen, call the right path, and recover gracefully if backend actions fail.
  - directional fallback logic
  - switching between Hammerspoon-native and yabai paths
  - command routing + consistent feedback
This split gives me Linux-like WM behavior on macOS while keeping the core logic scriptable in Lua.