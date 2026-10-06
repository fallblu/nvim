-- lazy.nvim manages plugins; it does not install the LazyVim distribution.
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.uv.fs_stat(lazypath) then
	local result = vim.fn.system({
		"git",
		"clone",
		"--filter=blob:none",
		"--branch=stable",
		"https://github.com/folke/lazy.nvim.git",
		lazypath,
	})
	if vim.v.shell_error ~= 0 then
		error("Could not install lazy.nvim: " .. result)
	end
end
vim.opt.rtp:prepend(lazypath)

require("lazy").setup({
	{
		"rebelot/kanagawa.nvim",
		priority = 1000,
		config = function()
			require("kanagawa").setup({ theme = "dragon", background = { dark = "dragon", light = "lotus" } })
			vim.cmd.colorscheme("kanagawa-dragon")
		end,
	},
	{ "nvim-mini/mini.statusline", branch = "stable", opts = { use_icons = false } },
	{
		"folke/which-key.nvim",
		event = "VeryLazy",
		opts = {
			preset = "modern",
			delay = 300,
			icons = { mappings = false },
			-- Keep key labels readable with a standard terminal font.
			replace = { key = {
				function(key)
					return key
				end,
			} },
			spec = {
				{ "<leader>c", group = "Code" },
				{ "<leader>d", group = "Debug" },
				{ "<leader>m", group = "C++ programs" },
				{ "<leader>p", group = "Python" },
				{ "<leader>s", group = "Search" },
				{ "<leader>t", group = "Terminals" },
				{ "<leader>u", group = "Editing toggles" },
				{ "<leader>w", group = "Windows" },
				{ "gr", group = "LSP" },
			},
		},
	},
	{
		"nvim-mini/mini.pick",
		branch = "stable",
		config = function()
			local pick = require("mini.pick")
			local project = require("config.project")
			pick.setup({
				mappings = {
					choose_in_split = "<C-x>",
					choose_in_vsplit = "<C-v>",
					choose_in_tabpage = "<C-t>",
					-- Ctrl+x now splits, so marking moves to Ctrl+k.
					mark = "<C-k>",
				},
				window = {
					config = {
						border = "rounded",
						footer = " C-v: right | C-x: below | Tab: preview ",
						footer_pos = "center",
					},
				},
			})

			vim.keymap.set("n", "<leader><space>", function()
				pick.builtin.files({ tool = "rg" }, { source = { cwd = project.root() } })
			end, { desc = "Find project file" })
			vim.keymap.set("n", "<leader>/", function()
				pick.builtin.grep_live({ tool = "rg" }, { source = { cwd = project.root() } })
			end, { desc = "Search project text" })
			vim.keymap.set("n", "<leader>,", pick.builtin.buffers, { desc = "Choose buffer" })
			vim.keymap.set("n", "<leader>sh", pick.builtin.help, { desc = "Search help" })
		end,
	},
	{
		"saghen/blink.cmp",
		version = "v1.10.2", -- Compatible with Neovim 0.11; reviewed acceptance behavior.
		dependencies = { "rafamadriz/friendly-snippets" },
		opts = function()
			return require("config.completion")
		end,
	},
	{
		"windwp/nvim-autopairs",
		-- Load the toggle and Enter guard even before the first InsertEnter.
		config = function()
			require("config.pairs")
		end,
	},
	{
		"stevearc/conform.nvim",
		config = function()
			require("config.format")
		end,
	},
	{
		"vim-test/vim-test",
		config = function()
			require("config.python")
		end,
	},
	{
		"mfussenegger/nvim-dap",
		-- Last revision before requiring Neovim 0.11.7; includes terminal reuse fixes.
		commit = "bd3e14aa277aed6a5e73b65f4dd2ad193a4a79d1",
		config = function()
			require("config.debug")
		end,
	},
	{
		"neovim/nvim-lspconfig",
		dependencies = { { "mason-org/mason.nvim", opts = {} }, "saghen/blink.cmp" },
		config = function()
			require("config.lsp")
		end,
	},
}, {
	checker = { enabled = false },
	change_detection = { notify = false },
	rocks = { enabled = false },
	-- Keep the system runtime paths, including Ubuntu's bundled parsers.
	performance = { rtp = { reset = false } },
})
