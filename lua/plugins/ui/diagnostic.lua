--- @module plugins.ui.diagnostic
--- @brief Diagnostic display and lsp_lines.nvim.
--- Configures diagnostic signs, disables virtual text by default, and adds
--- lsp_lines for togglable multiline diagnostic display (<leader>l).

vim.pack.add({ "https://git.sr.ht/~whynothugo/lsp_lines.nvim" })

require("lsp_lines").setup()

vim.diagnostic.config({
	virtual_lines = false,
	virtual_text = false,
	signs = true,
	underline = true,
	update_in_insert = false,
	severity_sort = true,
})

local signs = { Error = "x", Warn = "!", Hint = "h", Info = "i" }
for type, icon in pairs(signs) do
	local hl = "DiagnosticSign" .. type
	vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = "" })
end

vim.keymap.set({ "n", "x", "o" }, "<leader>l", require("lsp_lines").toggle, { desc = "Toggle multiline diagnostic errors inline under code" })
