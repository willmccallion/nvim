--- @file undotree.lua
--- @brief Configuration for the Undotree plugin.
--- @details This file manages the loading and keymapping for the Undotree plugin,
--- which allows users to visualize and navigate the undo tree.

vim.pack.add({ "https://github.com/mbbill/undotree" })

vim.keymap.set("n", "<leader>u", vim.cmd.UndotreeToggle, { desc = "Toggle [U]ndoTree" })
