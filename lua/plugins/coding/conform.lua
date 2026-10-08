--- Code formatting via conform.nvim.
--- Format-on-save for Rust (rustfmt), C/C++ (clang-format), Lua (stylua),
--- Python (ruff), Nix (nixfmt), and SystemVerilog/Verilog (verible).
--- Disable per-buffer with vim.b.autoformat = false.

vim.pack.add({ "https://github.com/stevearc/conform.nvim" })

require("conform").setup({
	formatters_by_ft = {
		rust = { "rustfmt" },
		c = { "clang-format" },
		cpp = { "clang-format" },
		lua = { "stylua" },
		python = { "ruff_organize_imports", "ruff_format" },
		nix = { "nixfmt" },
		systemverilog = { "verible" },
		verilog = { "verible" },
	},
	format_on_save = function(bufnr)
		if vim.g.autoformat == false or vim.b[bufnr].autoformat == false then
			return
		end
		return { timeout_ms = 2000, lsp_format = "fallback" }
	end,
})

vim.keymap.set({ "n", "x" }, "<leader>cf", function()
	require("conform").format({ async = true, lsp_format = "fallback" })
end, { desc = "Code format buffer or selection" })
