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
		python = { "isort", "black" },
	},
	format_on_save = function(bufnr)
		if vim.g.autoformat == false or vim.b[bufnr].autoformat == false then
			return
		end
		return { timeout_ms = 500, lsp_fallback = true }
	end,
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
	require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format code in current buffer (prettier rustfmt stylua)" })
