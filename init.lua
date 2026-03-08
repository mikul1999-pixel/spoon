local config  = require("config")
local utils   = require("utils")
local apps    = require("apps")
local window  = require("window")
local layouts = require("layouts")

hs.alert.show("Hammerspoon loaded")


-- Reload config on .lua changes
local function reloadConfig(files)
  for _, file in pairs(files) do
    if file:sub(-4) == ".lua" then
      hs.reload()
      return
    end
  end
end

local watcher = hs.pathwatcher.new(os.getenv("HOME") .. "/.hammerspoon/", reloadConfig)
watcher:start()