--- @module plugins.ui.diagnostic
--- @brief Diagnostic display.
--- Configures diagnostic signs, disables virtual text by default, and toggles
--- Neovim's native multiline diagnostics (virtual_lines) with <leader>l.

vim.diagnostic.config({
	virtual_lines = false,
	virtual_text = false,
	signs = {
		text = {
			[vim.diagnostic.severity.ERROR] = "x",
			[vim.diagnostic.severity.WARN] = "!",
			[vim.diagnostic.severity.INFO] = "i",
			[vim.diagnostic.severity.HINT] = "h",
		},
	},
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

vim.keymap.set("n", "<leader>l", function()
	vim.diagnostic.config({ virtual_lines = not vim.diagnostic.config().virtual_lines })
end, { desc = "Toggle multiline diagnostic errors inline under code" })
