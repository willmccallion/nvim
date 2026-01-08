vim.pack.add({'https://github.com/stevearc/oil.nvim'})
vim.pack.add({'https://github.com/nvim-tree/nvim-web-devicons'})

require('oil').setup({
  default_file_explorer = true,
  columns = { "icon" },
})

vim.keymap.set("n", "<leader>e", "<CMD>Oil<CR>", { desc = "Open parent directory" })
