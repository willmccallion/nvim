vim.pack.add({"https://github.com/folke/todo-comments.nvim"})

require('todo-comments').setup({
})

vim.keymap.set("n", "<leader>st", "<cmd>TodoTelescope<cr>", { desc = "[S]earch [T]ODOS" })
