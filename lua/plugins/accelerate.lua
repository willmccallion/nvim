--- @file accelerate.lua
--- @brief Configuration for the accelerated-jk plugin to enhance vertical navigation.
--- @details This file handles the installation and configuration of the
--- accelerated-jk plugin, which increases cursor movement speed when 'j' or 'k'
--- are held down.

vim.pack.add({ "https://github.com/rhysd/accelerated-jk" })

vim.g.accelerated_jk_acceleration_table = { 7, 12, 17, 21, 24, 26, 28, 30 }

vim.keymap.set("n", "j", "<Plug>(accelerated_jk_gj)", { desc = "Accelerated Scroll Down" })
vim.keymap.set("n", "k", "<Plug>(accelerated_jk_gk)", { desc = "Accelerated Scroll Up" })
