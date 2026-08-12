-- Wire the pytest adapter into the neotest instance from the test.core extra.
-- LazyVim's test extra already provides <leader>tt/tT/tr/ts/tw/tl keymaps.

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
