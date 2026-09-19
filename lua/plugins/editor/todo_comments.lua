--- Highlight and search TODO/FIXME/HACK comments.
--- <leader>st to search all tagged comments via Telescope.

vim.pack.add({ "https://github.com/folke/todo-comments.nvim" })

require("todo-comments").setup({})

vim.keymap.set("n", "<leader>st", "<Cmd>TodoTelescope<CR>", { desc = "Search TODO FIXME HACK notes in code" })
