local M = {}

-- Centralized modal mode manager for directional flow
local _spoonPath
local _alerts

local _modes = {}
local _active = nil

local function setActive(name)
  _active = name
end

function M:init(p)
  _spoonPath = p
  _alerts = dofile(_spoonPath .. "ui/alerts.lua")
end

function M:reset()
  _modes = {}
  _active = nil
end

function M:active()
  return _active
end

function M:isActive(name)
  return _active == name
end

function M:exit(name)
  if name and _active ~= name then return false end
  if not _active then return false end

  local entry = _modes[_active]
  if not entry then
    _active = nil
    return false
  end

  entry.modal:exit()
  return true
end

function M:enter(name)
  local entry = _modes[name]
  if not entry then return false end

  if _active and _active ~= name then
    self:exit(_active)
  end

  entry.modal:enter()
  return true
end

local function bindDirectional(modal, handler)
  local keys = {
    h = "left",
    j = "down",
    k = "up",
    l = "right",
  }

  for key, dir in pairs(keys) do
    modal:bind("", key, function()
      handler(dir)
    end)
  end
end

function M:register(name, spec)
  if type(name) ~= "string" or name == "" then return false end
  if _modes[name] then return true end

  spec = spec or {}
  local modal = hs.hotkey.modal.new()

  function modal:entered()
    setActive(name)
    if spec.enterMessage then _alerts.show(spec.enterMessage) end
    if spec.onEnter then spec.onEnter() end
  end

  function modal:exited()
    if _active == name then setActive(nil) end
    if spec.exitMessage then _alerts.show(spec.exitMessage) end
    if spec.onExit then spec.onExit() end
  end

  if spec.onDirection then
    bindDirectional(modal, spec.onDirection)
  end

  for _, b in ipairs(spec.bindings or {}) do
    modal:bind(b.mods or "", b.key, function()
      b.fn()
      if b.exit then
        M:exit(name)
      end
    end)
  end

  modal:bind("", "escape", function()
    M:exit(name)
  end)

  _modes[name] = {
    modal = modal,
    spec = spec,
  }

  return true
end

return M
