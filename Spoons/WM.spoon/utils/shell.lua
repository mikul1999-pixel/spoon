local M = {}

-- Shell execution helper to call backend commands

local function quote(arg)
  local s = tostring(arg or "")
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

function M.exec(path, args)
  -- Executes a command with quoted arguments. returns status and output
  local cmd = quote(path)
  for _, arg in ipairs(args or {}) do
    cmd = cmd .. " " .. quote(arg)
  end

  local out, ok, _, rc = hs.execute(cmd, true)
  return ok, out or "", rc or 0, cmd
end

return M
