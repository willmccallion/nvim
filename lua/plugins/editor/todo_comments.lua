--- @module plugins.todo_comments
--- @brief Configuration for the todo-comments.nvim plugin.
--- @description This module handles the setup and keybindings for todo-comments.nvim,
--- allowing for highlighting and searching of TODO, FIXME, and other comment tags.

vim.pack.add({ "https://github.com/folke/todo-comments.nvim" })

require("todo-comments").setup({})

vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "Search TODO FIXME HACK notes in code" })
