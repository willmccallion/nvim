--- @file flash.lua
--- @brief Configuration and initialization for the flash.nvim plugin.
--- @details This script manages the installation of the flash.nvim plugin,
--- performs the initial setup, and configures keybindings for jumping.

vim.pack.add({ "https://github.com/folke/flash.nvim" })

require("flash").setup({})

vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash Jump" })
