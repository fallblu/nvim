-- Wire the pytest adapter into the existing neotest instance. Its test
-- integration already provides <leader>tt/tT/tr/ts/tw/tl keymaps.

return {
  {
    "nvim-neotest/neotest",
    optional = true,
    dependencies = { "nvim-neotest/neotest-python" },
    opts = {
      adapters = {
        ["neotest-python"] = {
          runner = "pytest",
        },
      },
    },
  },
}
