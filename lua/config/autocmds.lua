--- @module config.autocmds
--- @brief Configuration for Neovim autocommands.
--- @description This module defines autocommands that automate editor behavior based on specific events, such as highlighting text on yank.

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})
