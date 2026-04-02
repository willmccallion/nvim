--- @module plugins.editor.todo_comments
--- @brief Highlight and search TODO/FIXME/HACK comments.
--- <leader>st to search all tagged comments via Telescope.

vim.pack.add({ "https://github.com/folke/todo-comments.nvim" })

require("todo-comments").setup({})

vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "Search TODO FIXME HACK notes in code" })
