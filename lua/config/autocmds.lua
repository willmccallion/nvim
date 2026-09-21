--- Global autocommands.
--- Highlight text briefly after yanking or putting it.

vim.api.nvim_create_autocmd({ "TextYankPost", "TextPutPost" }, {
	desc = "Highlight the text a yank or a put just covered",
	group = vim.api.nvim_create_augroup("highlight-yank", { clear = true }),
	callback = function()
		vim.hl.hl_op()
	end,
})
