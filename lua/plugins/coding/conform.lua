--- @module plugins.conform
--- @brief Configuration for conform.nvim to handle code formatting.
--- @details This module sets up the conform.nvim plugin, defining formatters for specific
--- filetypes (Rust, C, C++, Lua), enabling format-on-save, and providing a manual
--- formatting keybind.

vim.pack.add({ "https://github.com/stevearc/conform.nvim" })

require("conform").setup({
	formatters_by_ft = {
		rust = { "rustfmt" },
		c = { "clang-format" },
		cpp = { "clang-format" },
		lua = { "stylua" },
	},
	format_on_save = {
		timeout_ms = 500,
		lsp_fallback = true,
	},
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer" })
