local function codex_cli(action, opts)
  return function()
    local resolved = vim.tbl_deep_extend("force", { name = "codex" }, opts or {})
    require("sidekick.cli")[action](resolved)
  end
end

local function codex_prompt()
  require("sidekick.cli").prompt({
    cb = function(_, text)
      if text then
        require("sidekick.cli").send({ name = "codex", text = text })
      end
    end,
  })
end

local tmux = require("config.tmux")

return {
  {
    "folke/sidekick.nvim",
    opts = {
      -- Codex CLI integration does not require Copilot's next-edit service.
      nes = { enabled = false },
      cli = {
        mux = {
          backend = "tmux",
          enabled = true,
          create = "terminal",
        },
        win = {
          keys = {
            nav_left = { "<C-h>", tmux.sidekick_key("h"), desc = "Go to left window or tmux pane" },
            nav_down = { "<C-j>", tmux.sidekick_key("j"), desc = "Go to lower window or tmux pane" },
            nav_up = { "<C-k>", tmux.sidekick_key("k"), desc = "Go to upper window or tmux pane" },
            nav_right = { "<C-l>", tmux.sidekick_key("l"), desc = "Go to right window or tmux pane" },
          },
        },
      },
    },
    keys = {
      { "<C-.>", codex_cli("focus"), desc = "Focus Codex", mode = { "n", "t", "i", "x" } },
      { "<leader>aa", codex_cli("toggle"), desc = "Toggle Codex" },
      { "<leader>ad", codex_cli("close"), desc = "Detach Codex session" },
      {
        "<leader>at",
        codex_cli("send", { msg = "{this}" }),
        desc = "Send this to Codex",
        mode = { "n", "x" },
      },
      { "<leader>af", codex_cli("send", { msg = "{file}" }), desc = "Send file to Codex" },
      {
        "<leader>av",
        codex_cli("send", { msg = "{selection}" }),
        desc = "Send selection to Codex",
        mode = "x",
      },
      { "<leader>ap", codex_prompt, desc = "Select Codex prompt", mode = { "n", "x" } },
    },
  },
}
