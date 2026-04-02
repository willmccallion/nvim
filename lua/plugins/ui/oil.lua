--- @module plugins.ui.oil
--- @brief File explorer via oil.nvim.
--- Edit the filesystem as a buffer. <leader>e opens parent dir, <leader>E floats.

vim.pack.add({ "https://github.com/stevearc/oil.nvim" })
vim.pack.add({ "https://github.com/nvim-tree/nvim-web-devicons" })

require("oil").setup({
	default_file_explorer = true,
	columns = { "icon" },
})

vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>", { desc = "Open file explorer in parent directory" })
vim.keymap.set("n", "<leader>E", require("oil").toggle_float, { desc = "Open file explorer floating window" })
