--- @module plugins.which_key
--- @brief Configuration for the which-key.nvim plugin.
--- @description This module loads and initializes which-key.nvim, which displays
--- a popup with available keybindings to assist with command discovery and
--- keyboard shortcut memorization.

vim.pack.add({ "https://github.com/folke/which-key.nvim" })

require("which-key").setup({
	-- Defaults are usually fine to start
})
