--- @module accelerate
--- @brief Configuration for the accelerated-jk plugin.
--- @description This module handles the installation and configuration of the
--- accelerated-jk plugin, which speeds up cursor movement when the j or k keys
--- are held down. It defines the acceleration steps and sets up the keymaps.

vim.pack.add({ "https://github.com/rhysd/accelerated-jk" })

vim.g.accelerated_jk_acceleration_table = { 7, 12, 17, 21, 24, 26, 28, 30 }

vim.keymap.set("n", "j", "<Plug>(accelerated_jk_gj)", { desc = "Accelerated Scroll Down" })
vim.keymap.set("n", "k", "<Plug>(accelerated_jk_gk)", { desc = "Accelerated Scroll Up" })
