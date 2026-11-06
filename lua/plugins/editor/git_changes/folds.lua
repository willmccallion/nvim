--- Collapses a file to its changes: the lines more than a few away from any hunk
--- are folded away. The folds are manual ones, since a fold expression would be
--- replaced by the language server's when it attaches. A window's own fold
--- settings for the buffer are put back on release, or, for a buffer that has
--- left the window by then, the next time it is shown there. Previews can show their
--- whole files instead, for the rest of the session, with toggle_whole_files.

local CONTEXT_LINES = 3

---@class GitHunk
---@field added {start: integer, count: integer}
---@field removed {start: integer, count: integer}

---@class FoldRange
---@field first integer
---@field last integer

---@class SavedFoldOptions
---@field foldmethod string
---@field foldlevel integer
---@field released boolean

---@type table<integer, table<integer, SavedFoldOptions>> by window, then buffer
local saved = {}

--- The hunks of each buffer under review, by window then buffer, to fold it again
--- when whole files are toggled off.
---@type table<integer, table<integer, GitHunk[]>>
local reviewed = {}

local shows_whole_files = false

local M = {}

--- A deletion has no added lines; it sits after added.start, which is 0 at the top.
---@param hunks GitHunk[] in buffer order
---@param line_count integer
---@return FoldRange[]
function M.unchanged_ranges(hunks, line_count)
	local ranges = {}
	local next_line = 1
	for _, hunk in ipairs(hunks) do
		local first = math.max(hunk.added.start, 1)
		local last = first + math.max(hunk.added.count, 1) - 1
		local keep_from = math.max(first - CONTEXT_LINES, 1)
		if keep_from > next_line then
			table.insert(ranges, { first = next_line, last = keep_from - 1 })
		end
		next_line = math.max(next_line, last + CONTEXT_LINES + 1)
	end
	if next_line <= line_count then
		table.insert(ranges, { first = next_line, last = line_count })
	end
	return ranges
end

---@param win integer
---@param buf integer
---@param options SavedFoldOptions
local function restore(win, buf, options)
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zE")
		vim.wo[win][0].foldmethod = options.foldmethod
		vim.wo[win][0].foldlevel = options.foldlevel
	end)
	saved[win][buf] = nil
end

--- Folds everything but the hunks and their context in win, which must show buf,
--- unless previews show whole files.
---@param win integer
---@param buf integer
---@param hunks GitHunk[]
function M.collapse(win, buf, hunks)
	reviewed[win] = reviewed[win] or {}
	reviewed[win][buf] = hunks
	local ranges = M.unchanged_ranges(hunks, vim.api.nvim_buf_line_count(buf))
	saved[win] = saved[win] or {}
	if shows_whole_files or #hunks == 0 or #ranges == 0 then
		if saved[win][buf] then
			restore(win, buf, saved[win][buf])
		end
		return
	end

	saved[win][buf] = saved[win][buf] or { foldmethod = vim.wo[win].foldmethod, foldlevel = vim.wo[win].foldlevel }
	saved[win][buf].released = false
	vim.api.nvim_win_call(win, function()
		vim.wo[win][0].foldmethod = "manual"
		vim.cmd("normal! zE")
		for _, range in ipairs(ranges) do
			vim.cmd(("%d,%dfold"):format(range.first, range.last))
		end
		vim.wo[win][0].foldlevel = 0
	end)
end

--- Switches previews between their whole files and their changes, folding or
--- unfolding the ones on show now, and keeping the choice until nvim quits.
---@return boolean shows_whole_files
function M.toggle_whole_files()
	shows_whole_files = not shows_whole_files
	for win, buffers in pairs(reviewed) do
		local hunks = vim.api.nvim_win_is_valid(win) and buffers[vim.api.nvim_win_get_buf(win)]
		if hunks then
			M.collapse(win, vim.api.nvim_win_get_buf(win), hunks)
			vim.api.nvim_win_call(win, function()
				vim.cmd("normal! zv")
			end)
		end
	end
	return shows_whole_files
end

--- Restores every collapsed buffer still on show, and marks the rest to be
--- restored when they are next shown in the window they were collapsed in.
function M.release_all()
	reviewed = {}
	for win, buffers in pairs(saved) do
		if not vim.api.nvim_win_is_valid(win) then
			saved[win] = nil
		else
			local shown = vim.api.nvim_win_get_buf(win)
			for buf, options in pairs(buffers) do
				if buf == shown then
					restore(win, buf, options)
				else
					options.released = true
				end
			end
		end
	end
end

local group = vim.api.nvim_create_augroup("git-changes-folds", { clear = true })

vim.api.nvim_create_autocmd("BufWinEnter", {
	desc = "Restore the folds of a buffer collapsed for review once the review is over",
	group = group,
	callback = function(ev)
		local win = vim.api.nvim_get_current_win()
		local options = saved[win] and saved[win][ev.buf]
		if options and options.released and vim.api.nvim_win_get_buf(win) == ev.buf then
			restore(win, ev.buf, options)
		end
	end,
})

vim.api.nvim_create_autocmd("BufWipeout", {
	desc = "Forget the saved fold settings of a wiped buffer",
	group = group,
	callback = function(ev)
		for _, buffers in pairs(saved) do
			buffers[ev.buf] = nil
		end
		for _, buffers in pairs(reviewed) do
			buffers[ev.buf] = nil
		end
	end,
})

return M
