--- @module plugins.editor.undotree
--- @brief Visual undo history tree via Neovim's bundled nvim.undotree package.
--- <leader>u toggles the tree; moving the cursor in it steps through history.

vim.cmd.packadd("nvim.undotree")

vim.keymap.set("n", "<leader>u", vim.cmd.Undotree, { desc = "Undo toggle history tree" })
