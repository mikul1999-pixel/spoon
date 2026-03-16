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
| `hyper+\` | Cycle local stack (on same screen) |
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

- Hammerspoon is the policy/control layer (modes, intent, fallback logic, and UI), while yabai is the execution backend for tiled operations.
- Some actions are handled entirely in Hammerspoon, but its main role is orchestration: deciding what should happen and recovering when backend actions fail.
  - intelligent fallbacks (directional intent + looping, switching between Hammerspoon-native and yabai paths)
  - command handling
  - consistent feedback (UI + logging)
  
This split lets me combine Hammerspoon and yabai to mirror Linux-like WM behavior, while keeping the logic scriptable in Lua.