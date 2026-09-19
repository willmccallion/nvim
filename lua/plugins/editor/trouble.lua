--- Diagnostic and symbol browser via Trouble.nvim.
--- Diagnostics and quickfix lists under <leader>x; symbol outline under <leader>co.

vim.pack.add({ "https://github.com/folke/trouble.nvim" })

require("trouble").setup()

vim.keymap.set(
	"n",
	"<leader>xx",
	"<cmd>Trouble diagnostics toggle win.position=right win.size=0.4 win.wo.wrap=true win.wo.linebreak=true win.wo.breakindent=true<cr>",
	{ desc = "Problems toggle project errors and warnings list" }
)
vim.keymap.set(
	"n",
	"<leader>xb",
	"<cmd>Trouble diagnostics toggle filter.buf=0<cr>",
	{ desc = "Problems toggle current buffer list" }
)
vim.keymap.set(
	"n",
	"<leader>co",
	"<cmd>Trouble symbols toggle focus=false<cr>",
	{ desc = "Code toggle symbol outline sidebar (functions classes)" }
)
vim.keymap.set(
	"n",
	"<leader>xq",
	"<cmd>Trouble qflist toggle<cr>",
	{ desc = "Problems toggle quickfix list in Trouble view" }
)
