--- @module plugins.colourscheme
--- @brief Configuration for the Neovim colorscheme.
--- @description This module handles the installation and configuration of the Nightfox
--- colorscheme family, specifically applying the Terafox variant with transparency.

vim.pack.add({ 
  "https://github.com/EdenEast/nightfox.nvim",
  "https://github.com/folke/tokyonight.nvim",
})

require("nightfox").setup({
	options = {
		transparent = true,
	},
})

require("tokyonight").setup({
	transparent = true,
  style = "night",
})

vim.cmd([[colorscheme tokyonight]])
