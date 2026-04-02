--- @module plugins.editor.trouble
--- @brief Diagnostic and symbol browser via Trouble.nvim.
--- Pretty list for diagnostics, symbols, and quickfix under <leader>d.

vim.pack.add({ "https://github.com/folke/trouble.nvim" })

require("trouble").setup()

vim.keymap.set("n", "<leader>dd", "<cmd>Trouble diagnostics toggle<cr>", { desc = "Toggle all project diagnostics errors warnings" })
vim.keymap.set("n", "<leader>db", "<cmd>Trouble diagnostics toggle filter.buf=0<cr>", { desc = "Toggle diagnostics for current buffer only" })
vim.keymap.set("n", "<leader>ds", "<cmd>Trouble symbols toggle focus=false<cr>", { desc = "Toggle symbols outline sidebar (functions classes)" })
vim.keymap.set("n", "<leader>df", "<cmd>Trouble qflist toggle<cr>", { desc = "Toggle quickfix list in trouble view" })
