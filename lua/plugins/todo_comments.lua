--- @file todo_comments.lua
--- @brief Configuration for the todo-comments.nvim plugin.
--- @details This file handles the installation, setup, and keybindings for
--- managing TODO, FIXME, and other comment tags using todo-comments.nvim.

vim.pack.add({ "https://github.com/folke/todo-comments.nvim" })

require("todo-comments").setup({})

vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "[S]earch [T]ODOS" })
