local M = {}

local commands = {
  h = "TmuxNavigateLeft",
  j = "TmuxNavigateDown",
  k = "TmuxNavigateUp",
  l = "TmuxNavigateRight",
}

---@param direction "h"|"j"|"k"|"l"
function M.navigate(direction)
  vim.cmd(commands[direction])
end

---@param direction "h"|"j"|"k"|"l"
function M.sidekick_key(direction)
  return function()
    vim.schedule(function()
      M.navigate(direction)
    end)
  end
end

---@param direction "h"|"j"|"k"|"l"
function M.snacks_key(direction)
  return function(terminal)
    if terminal:is_floating() then
      return "<C-" .. direction .. ">"
    end
    vim.schedule(function()
      M.navigate(direction)
    end)
  end
end

return M
