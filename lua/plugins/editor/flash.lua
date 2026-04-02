--- @module plugins.flash
--- @brief Configuration for flash.nvim to navigate code with search labels.
--- @description This module handles the installation, setup, and keybindings for flash.nvim,
--- providing a fast and intuitive way to jump to any location in the buffer using
--- search-based labels.

vim.pack.add({ "https://github.com/folke/flash.nvim" })

require("flash").setup({})

vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash jump to any visible text with search labels" })
