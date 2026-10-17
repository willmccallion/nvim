--- Global autocommands.
--- Highlight text briefly after yanking or putting it, reopen files where they
--- were left, and reload files that change on disk while open.

local group = vim.api.nvim_create_augroup("config-autocmds", { clear = true })

vim.api.nvim_create_autocmd({ "TextYankPost", "TextPutPost" }, {
	desc = "Highlight the text a yank or a put just covered",
	group = group,
	callback = function()
		vim.hl.hl_op()
	end,
})

--- Commit messages and rebase todos are new text each time, so they start at the top.
local START_AT_TOP_FILETYPES = { "gitcommit", "gitrebase" }

vim.api.nvim_create_autocmd("BufReadPost", {
	desc = "Put the cursor back where it was when the file was last closed",
	group = group,
	callback = function(ev)
		if vim.bo[ev.buf].buftype ~= "" then
			return
		end
		-- Matched here: filetype detection is set up after init.lua, so it runs after this.
		if vim.list_contains(START_AT_TOP_FILETYPES, vim.filetype.match({ buf = ev.buf })) then
			return
		end
		local last = vim.api.nvim_buf_get_mark(ev.buf, '"')
		if last[1] > 0 and last[1] <= vim.api.nvim_buf_line_count(ev.buf) then
			vim.api.nvim_win_set_cursor(0, last)
		end
	end,
})

--- 'autoread' only acts when Neovim checks, which it does not on its own after a
--- write from elsewhere. CursorHold covers tmux, which withholds focus events.
vim.api.nvim_create_autocmd({ "FocusGained", "BufEnter", "CursorHold" }, {
	desc = "Reload files changed outside Neovim",
	group = group,
	callback = function()
		-- :checktime is not allowed in the command-line window.
		if vim.fn.getcmdwintype() == "" then
			vim.cmd.checktime()
		end
	end,
})

vim.api.nvim_create_autocmd("FileChangedShellPost", {
	desc = "Say when a file was reloaded because it changed on disk",
	group = group,
	callback = function(ev)
		-- Still modified means the reload was declined; gone means it was deleted.
		if vim.bo[ev.buf].modified or not vim.uv.fs_stat(ev.file) then
			return
		end
		vim.notify("Reloaded " .. vim.fn.fnamemodify(ev.file, ":~:.") .. " (changed on disk)")
	end,
})
