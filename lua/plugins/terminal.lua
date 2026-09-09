-- Terminal keymaps backed by snacks.nvim.
--
-- Layout:
--   <C-/>          toggle the project-root terminal
--   <leader>;<x>   terminal-group prefix (chosen to avoid colliding with
--                  <leader>t* which the test extra owns)
--
-- Each shell layout has its own terminal identity. Toggling a key therefore
-- closes/reopens that layout's shell without colliding with the others.

local terminal = require("config.terminal")

---@param cmd? string|string[]|fun(root: string):(string[]?, string?)
---@param opts? table
local function snacks_term(cmd, opts)
  return function()
    local root = terminal.root()
    local resolved, message
    if type(cmd) == "function" then
      resolved, message = cmd(root)
    else
      resolved = cmd
    end
    if cmd ~= nil and resolved == nil then
      vim.notify(message or "No suitable command is available", vim.log.levels.ERROR, { title = "Terminal" })
      return
    end

    opts = vim.deepcopy(opts or {})
    opts.cwd = root
    require("snacks").terminal(resolved, opts)
  end
end

local keys = {
  { "<leader>;", "", desc = "+terminal" },
  {
    "<leader>;t",
    snacks_term(nil, { count = 2, win = { position = "float" } }),
    desc = "Terminal (float)",
  },
  {
    "<leader>;s",
    snacks_term(nil, { count = 3, win = { position = "bottom", height = 0.4 } }),
    desc = "Terminal (hsplit)",
  },
  {
    "<leader>;v",
    snacks_term(nil, { count = 4, win = { position = "right", width = 0.4 } }),
    desc = "Terminal (vsplit)",
  },
  {
    "<leader>;p",
    snacks_term(function(root)
      return terminal.python_command(root)
    end, { count = 5, win = { position = "right", width = 0.45 } }),
    desc = "Python REPL",
  },
  {
    "<leader>;r",
    snacks_term(function(root)
      return terminal.pytest_command(root)
    end, { count = 6, win = { position = "bottom", height = 0.4 } }),
    desc = "pytest (run all)",
  },
  {
    "<leader>;l",
    snacks_term(function(root)
      if not terminal.directory_exists(vim.fs.joinpath(root, "tests", "live")) then
        return nil, "This project has no tests/live directory"
      end
      return terminal.pytest_command(root, { "--no-cov", "-m", "live", "-s", "tests/live" })
    end, {
      count = 7,
      env = { PERSISTRA_RUN_LIVE = "1" },
      win = { position = "bottom", height = 0.4 },
    }),
    desc = "pytest (run live suite)",
  },
}

if vim.fn.executable("lazygit") == 1 then
  keys[#keys + 1] = {
    "<leader>;g",
    function()
      require("snacks").lazygit({ cwd = terminal.root() })
    end,
    desc = "Lazygit",
  }
end

return {
  {
    "folke/snacks.nvim",
    keys = keys,
  },
}
