local M = {}

function M.bind(mods, key, fn)
  hs.hotkey.bind(mods, key, fn)
end

function M.findBinding(bindings, action)
  for _, b in ipairs(bindings) do
    if b.action == action then return b end
  end
end

return M
