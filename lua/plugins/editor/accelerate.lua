--- @module plugins.editor.accelerate
--- @brief Accelerated j/k vertical movement.
--- Cursor speed increases the longer j or k is held down.

vim.pack.add({ "https://github.com/rhysd/accelerated-jk" })

vim.g.accelerated_jk_acceleration_table = { 7, 12, 17, 21, 24, 26, 28, 30 }

vim.keymap.set("n", "j", "<Plug>(accelerated_jk_gj)", { desc = "Accelerated Scroll Down" })
vim.keymap.set("n", "k", "<Plug>(accelerated_jk_gk)", { desc = "Accelerated Scroll Up" })
