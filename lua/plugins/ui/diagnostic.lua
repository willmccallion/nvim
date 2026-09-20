--- Diagnostic display.
--- Messages appear under the cursor's line only, so the gutter stays quiet while
--- whatever you are looking at stays readable. <leader>ol widens that to every
--- line, and <leader>cd opens the full message in a float.

vim.diagnostic.config({
	virtual_lines = { current_line = true },
	virtual_text = false,
	float = { border = "rounded", source = true },
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
	local showing_every_line = vim.diagnostic.config().virtual_lines == true
	vim.diagnostic.config({ virtual_lines = showing_every_line and { current_line = true } or true })
end, { desc = "Option toggle diagnostic lines for every line or just the cursor line" })

vim.keymap.set("n", "<leader>cd", function()
	vim.diagnostic.open_float({ scope = "line" })
end, { desc = "Code show diagnostic message under cursor" })
