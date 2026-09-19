--- Diagnostic and symbol browser via Trouble.nvim.
--- Pretty list for diagnostics, symbols, and quickfix under <leader>d.

vim.pack.add({ "https://github.com/folke/trouble.nvim" })

require("trouble").setup()

vim.keymap.set(
	"n",
	"<leader>dd",
	"<cmd>Trouble diagnostics toggle win.position=right win.size=0.4 win.wo.wrap=true win.wo.linebreak=true win.wo.breakindent=true<cr>",
	{ desc = "Diagnostics toggle project errors and warnings list" }
)
vim.keymap.set(
	"n",
	"<leader>db",
	"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
	{ desc = "Diagnostics toggle current buffer list" }
)
vim.keymap.set(
	"n",
	"<leader>co",
	"<cmd>Trouble symbols toggle focus=false<cr>",
	{ desc = "Code toggle symbol outline sidebar (functions classes)" }
)
vim.keymap.set("n", "<leader>df", "<cmd>Trouble qflist toggle<cr>", { desc = "Quickfix toggle list in Trouble view" })
