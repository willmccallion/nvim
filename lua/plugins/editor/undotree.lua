--- @module plugins.editor.undotree
--- @brief Visual undo history tree.
--- <leader>u to toggle the undo tree sidebar.

vim.pack.add({ "https://github.com/mbbill/undotree" })

vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle undo history tree" })
