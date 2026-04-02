--- @module plugins.ui.colourscheme
--- @brief Colorscheme setup.
--- Installs Nightfox, Tokyonight, and Rose Pine with transparent backgrounds.
--- Active scheme: Tokyonight (night).

vim.pack.add({ 
  "https://github.com/EdenEast/nightfox.nvim",
  "https://github.com/folke/tokyonight.nvim",
  "https://github.com/rose-pine/neovim",
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

require("rose-pine").setup({
	variant = "moon",

	styles = {
		transparency = true,
	},
})

vim.cmd([[colorscheme tokyonight]])
