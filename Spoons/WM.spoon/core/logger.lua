local M = {}

-- logging.info idea. enable WM debugging in hammerspoon console by storing every event
local _state = {
  level = "warn",
  debug = false,
  maxEntries = 300,
  entries = {},
}

local _weights = {
  error = 1,
  warn = 2,
  info = 3,
  debug = 4,
  trace = 5,
}

local function shouldLog(level)
  local current = _weights[_state.level] or _weights.warn
  local wanted = _weights[level] or _weights.info
  return wanted <= current
end

local function push(entry)
  table.insert(_state.entries, entry)
  if #_state.entries > _state.maxEntries then
    table.remove(_state.entries, 1)
  end
end

local function emit(level, event, message, data)
  -- Store every event & mirror to console in debug mode
  local payload = {
    ts = os.date("%H:%M:%S"),
    level = level,
    event = event,
    message = message,
    data = data,
  }
  push(payload)

  if _state.debug and shouldLog(level) then
    local details = ""
    if data ~= nil then details = " " .. hs.inspect(data) end
    hs.printf("[wm.%s] %s: %s%s", level, event, tostring(message or ""), details)
  end
end

function M:init(_)
  return true
end

function M:configure(cfg)
  local debug = cfg and cfg.debug
  _state.debug = debug and debug.enabled or false
  _state.level = debug and debug.level or "warn"
  _state.maxEntries = debug and debug.maxEntries or 300
end

function M:setDebug(enabled)
  _state.debug = enabled and true or false
end

function M:toggleDebug()
  _state.debug = not _state.debug
  return _state.debug
end

function M:setLevel(level)
  if _weights[level] then _state.level = level end
end

function M:getLevel()
  return _state.level
end

function M:error(event, message, data)
  emit("error", event, message, data)
end

function M:warn(event, message, data)
  emit("warn", event, message, data)
end

function M:info(event, message, data)
  emit("info", event, message, data)
end

function M:debug(event, message, data)
  emit("debug", event, message, data)
end

function M:trace(event, message, data)
  emit("trace", event, message, data)
end

function M:last(n)
  -- Returns the most recent N log entries
  local count = tonumber(n) or 20
  if count < 1 then count = 1 end
  local start = math.max(1, #_state.entries - count + 1)
  local out = {}
  for i = start, #_state.entries do
    table.insert(out, _state.entries[i])
  end
  return out
end

return M
