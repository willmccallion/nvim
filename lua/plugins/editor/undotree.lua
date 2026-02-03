--- @module plugins.undotree
--- @brief Configuration for the undotree plugin.
--- @description This module handles the installation and keybinding setup for the undotree plugin,
--- which provides a visual representation of the undo history tree.

vim.pack.add({ "https://github.com/mbbill/undotree" })

vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle [U]ndoTree" })
