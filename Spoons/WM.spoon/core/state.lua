local M = {}

-- Shared WM state. need to track workspaces and scratchpads
local _state = {
  currentWorkspace = 1,
  scratchOrigins = {},
}

function M:reset()
  _state = {
    currentWorkspace = 1,
    scratchOrigins = {},
  }
end

function M:setCurrentWorkspace(workspaceId)
  if type(workspaceId) == "number" then
    _state.currentWorkspace = workspaceId
  end
end

function M:currentWorkspace()
  return _state.currentWorkspace
end

function M:setScratchOrigin(winId, workspaceId)
  if winId and workspaceId then
    _state.scratchOrigins[winId] = workspaceId
  end
end

function M:scratchOrigin(winId)
  return _state.scratchOrigins[winId]
end

function M:removeScratchOrigin(winId)
  _state.scratchOrigins[winId] = nil
end

function M:dump()
  return hs.inspect(_state)
end

return M
