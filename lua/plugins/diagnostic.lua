vim.pack.add({ "https://git.sr.ht/~whynothugo/lsp_lines.nvim" })

require("lsp_lines").setup()

vim.diagnostic.config({
	virtual_text = false,
	virtual_lines = true,
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

vim.keymap.set("", "<leader>l", require("lsp_lines").toggle, { desc = "Toggle LSP Lines" })
