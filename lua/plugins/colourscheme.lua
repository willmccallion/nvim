--- @file colourscheme.lua
--- @brief Configuration for the Neovim colorscheme.
--- @details This file handles the installation, configuration, and activation
--- of the 'nightfox.nvim' colorscheme, specifically the 'terafox' variant.

vim.pack.add({ "https://github.com/EdenEast/nightfox.nvim" })

require("nightfox").setup({
	options = {
		transparent = true,
	},
})

vim.cmd([[colorscheme terafox]])
