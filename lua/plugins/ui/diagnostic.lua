--- Diagnostic display.
--- Configures diagnostic signs, disables virtual text by default, and toggles
--- Neovim's native multiline diagnostics (virtual_lines) with <leader>ol.

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

vim.keymap.set("n", "<leader>ol", function()
	vim.diagnostic.config({ virtual_lines = not vim.diagnostic.config().virtual_lines })
end, { desc = "Option toggle multiline diagnostic lines under code" })
