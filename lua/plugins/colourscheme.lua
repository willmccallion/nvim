--- @module plugins.colourscheme
--- @brief Configuration for the Neovim colorscheme.
--- @description This module handles the installation and configuration of the Nightfox
--- colorscheme family, specifically applying the Terafox variant with transparency.

vim.pack.add({ "https://github.com/EdenEast/nightfox.nvim" })

require("nightfox").setup({
	options = {
		transparent = true,
	},
})

vim.cmd([[colorscheme terafox]])
