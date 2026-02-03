--- @module plugins.oil
--- @brief Configuration for oil.nvim file explorer.
--- This module handles the installation and setup of oil.nvim, which allows
--- editing the file system like a normal Neovim buffer.

vim.pack.add({ "https://github.com/stevearc/oil.nvim" })
vim.pack.add({ "https://github.com/nvim-tree/nvim-web-devicons" })

require("oil").setup({
	default_file_explorer = true,
	columns = { "icon" },
})

vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>", { desc = "Open parent directory" })
vim.keymap.set("n", "<leader>E", require("oil").toggle_float, { desc = "Open Oil (Float)" })
