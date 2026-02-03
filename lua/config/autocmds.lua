--- @file autocmds.lua
--- @brief Neovim autocommand configurations.
--- @details This script defines autocommands that trigger automatically on specific Neovim events.

vim.api.nvim_create_autocmd("TextYankPost", {
	desc = "Highlight when yanking (copying) text",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.highlight.on_yank()
	end,
})
