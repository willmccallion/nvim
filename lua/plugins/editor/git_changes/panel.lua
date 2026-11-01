--- The open panel and its preview: everything that depends on the panel's state.

local changes = require("plugins.editor.git_changes.changes")
local file_buffers = require("plugins.editor.git_changes.file_buffers")
local folds = require("plugins.editor.git_changes.folds")
local git = require("plugins.editor.git_changes.git")
local gitsigns_base = require("plugins.editor.git_changes.gitsigns_base")
local render = require("plugins.editor.git_changes.render")
local tint = require("plugins.editor.git_changes.tint")

local M = {}

local ns = vim.api.nvim_create_namespace("git-changes")
local edits_group = vim.api.nvim_create_augroup("git-changes-edits", { clear = true })

---@class Panel
---@field buf integer
---@field win integer
---@field root string
---@field width integer
---@field target_win integer the window files open in
---@field files_by_line table<integer, ChangedFile>
---@field preview_buf integer? a buffer the preview loaded, closed once superseded
---@field origin_buf integer the buffer the panel was opened from, shown again on close
---@field origin_view vim.fn.winsaveview.ret its view at the time
---@field since Since? nil for the uncommitted changes
---@field ready boolean false until gitsigns diffs against the panel's base, so no preview attaches early
---@field bases table<integer, BaseText> by buffer, each real file the preview tinted, to tint again on edits

---@class BaseText
---@field text string the file as the panel's base commit has it
---@field lines string[] the same, split into lines

---@type Panel?
local panel = nil

---@param files ChangedFile[]
local function draw(files)
	assert(panel, "draw needs an open panel")
	local cursor_line = vim.api.nvim_win_get_cursor(panel.win)[1]
	local file_under_cursor = panel.files_by_line[cursor_line]

	local content = render.content(files, changes.title_of(panel.since))
	vim.bo[panel.buf].modifiable = true
	vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, content.lines)
	vim.bo[panel.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(panel.buf, ns, 0, -1)
	for _, mark in ipairs(content.marks) do
		vim.api.nvim_buf_set_extmark(panel.buf, ns, mark.row, mark.col_start, {
			end_col = mark.col_end,
			hl_group = mark.group,
		})
	end
	panel.files_by_line = content.files_by_line

	local line = render.line_of(content.files_by_line, file_under_cursor and file_under_cursor.path) or 1
	vim.api.nvim_win_set_cursor(panel.win, { line, 0 })
end

local function refresh()
	if not panel then
		return
	end
	local files = changes.list(panel.root, panel.since)
	if files then
		draw(files)
	end
end

--- The window files open in: the one the panel was opened from while it lasts,
--- then any other window in the tabpage, then a new split on the right.
---@return integer
local function target_window()
	assert(panel, "target_window needs an open panel")
	local tabpage_wins = vim.api.nvim_tabpage_list_wins(0)
	if
		vim.api.nvim_win_is_valid(panel.target_win)
		and panel.target_win ~= panel.win
		and vim.list_contains(tabpage_wins, panel.target_win)
	then
		return panel.target_win
	end
	for _, win in ipairs(tabpage_wins) do
		if win ~= panel.win and vim.api.nvim_win_get_config(win).relative == "" then
			return win
		end
	end
	local placeholder = vim.api.nvim_create_buf(false, true)
	vim.bo[placeholder].bufhidden = "wipe"
	local win = vim.api.nvim_open_win(placeholder, false, { split = "right", win = -1 })
	vim.api.nvim_win_set_config(panel.win, { width = panel.width })
	return win
end

--- ]h and [h in a read-only copy, which gitsigns does not attach to: the first
--- line of the next or previous change.
---@param buf integer
---@param hunks GitHunk[]
local function map_hunk_motions(buf, hunks)
	local starts = {}
	for _, hunk in ipairs(hunks) do
		if hunk.added.count > 0 then
			table.insert(starts, hunk.added.start)
		end
	end
	local function go(forward)
		local line = vim.api.nvim_win_get_cursor(0)[1]
		local target
		for _, start in ipairs(starts) do
			if forward and start > line and not target then
				target = start
			elseif not forward and start < line then
				target = start
			end
		end
		if target then
			vim.api.nvim_win_set_cursor(0, { target, 0 })
		end
	end
	local next_hunk, prev_hunk = require("plugins.editor.motion_repeat").pair(function()
		go(true)
	end, function()
		go(false)
	end)
	vim.keymap.set("n", "]h", next_hunk, { buffer = buf, desc = "Git go to next changed hunk" })
	vim.keymap.set("n", "[h", prev_hunk, { buffer = buf, desc = "Git go to previous changed hunk" })
end

--- Collapses the file to its changes and puts the cursor on the first one.
---@param win integer
---@param buf integer
---@param hunks GitHunk[]
local function focus_changes(win, buf, hunks)
	folds.collapse(win, buf, hunks)
	if #hunks == 0 then
		return
	end
	vim.api.nvim_win_set_cursor(win, { math.max(hunks[1].added.start, 1), 0 })
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zz")
	end)
end

---@param file ChangedFile
---@return string
local function buffer_name_of(file)
	assert(panel, "buffer_name_of needs an open panel")
	if file.status == "D" then
		return file_buffers.deleted_buffer_name(file)
	end
	if changes.shows_copies(panel.since) then
		return file_buffers.copy_buffer_name(changes.end_name(panel.since.to), file)
	end
	return vim.fs.joinpath(panel.root, file.path)
end

--- Closes a buffer the preview loaded once nothing shows it, so looking down the
--- list does not leave every file open. One with unsaved edits stays.
---@param buf integer?
local function close_unused_preview(buf)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if vim.bo[buf].modified or #vim.fn.win_findbuf(buf) > 0 then
		return
	end
	vim.api.nvim_buf_delete(buf, {})
end

--- Keeps a real file's before and after up to date while it is edited in the review.
---@param buf integer
local function retint_on_edits(buf)
	if #vim.api.nvim_get_autocmds({ group = edits_group, buffer = buf }) > 0 then
		return
	end
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		desc = "Show the edited file's changes against the panel's base",
		group = edits_group,
		buffer = buf,
		callback = function()
			local base = panel and panel.bases[buf]
			if base then
				tint.show(buf, git.hunks_against(base.text, buf), base.lines, false)
			end
		end,
	})
end

--- Shows the file in the target window, at its first change, without moving there.
---@param file ChangedFile
---@return integer win
local function show_file(file)
	assert(panel, "show_file needs an open panel")
	local win = target_window()
	panel.target_win = win
	local previous_preview = panel.preview_buf
	if file.status == "D" then
		local buf = file_buffers.deleted_file_buffer(panel.root, panel.since, file)
		if buf then
			vim.api.nvim_win_set_buf(win, buf)
		end
		panel.preview_buf = nil
	elseif changes.shows_copies(panel.since) then
		local to = panel.since.to
		local name = file_buffers.copy_buffer_name(changes.end_name(to), file)
		local buf = file_buffers.git_file_buffer(panel.root, { changes.end_source(to) }, file.path, name)
		if buf then
			vim.api.nvim_win_set_buf(win, buf)
			local old_text = git.text_at(panel.root, panel.since.commit, file)
			local hunks = git.hunks_against(old_text, buf)
			tint.show(buf, hunks, vim.split(old_text, "\n", { plain = true }), true)
			map_hunk_motions(buf, hunks)
			focus_changes(win, buf, hunks)
		end
		panel.preview_buf = nil
	else
		local path = buffer_name_of(file)
		local loaded_before = file_buffers.buffer_named(path) ~= nil
		vim.api.nvim_win_call(win, function()
			vim.cmd.edit(vim.fn.fnameescape(path))
		end)
		local buf = vim.api.nvim_win_get_buf(win)
		local text = git.text_at(panel.root, changes.base_rev(panel.since), file)
		panel.bases[buf] = { text = text, lines = vim.split(text, "\n", { plain = true }) }
		local hunks = git.hunks_against(text, buf)
		tint.show(buf, hunks, panel.bases[buf].lines, false)
		retint_on_edits(buf)
		focus_changes(win, buf, hunks)
		panel.preview_buf = not loaded_before and buf or nil
	end
	if previous_preview ~= panel.preview_buf then
		close_unused_preview(previous_preview)
	end
	return win
end

--- Shows the file under the panel's cursor unless it already is.
---@return integer? win showing it, or nil on a folder line
local function show_file_under_cursor()
	if not panel or not panel.ready then
		return nil
	end
	local file = panel.files_by_line[vim.api.nvim_win_get_cursor(panel.win)[1]]
	if not file then
		return nil
	end
	local target = panel.target_win
	if vim.api.nvim_win_is_valid(target) then
		local shown = vim.api.nvim_win_get_buf(target)
		-- A real file already on show, like the one the panel was opened from, still
		-- needs its before and after drawn; copies and deleted files are drawn as made.
		local drawn = panel.bases[shown] or file.status == "D" or changes.shows_copies(panel.since)
		if drawn and vim.api.nvim_buf_get_name(shown) == buffer_name_of(file) then
			return target
		end
	end
	return show_file(file)
end

local function open_file_under_cursor()
	local win = show_file_under_cursor()
	if win then
		vim.api.nvim_set_current_win(win)
	end
end

---@param win integer
local function set_panel_window_options(win)
	local opts = vim.wo[win][0]
	opts.number = false
	opts.relativenumber = false
	opts.signcolumn = "no"
	opts.foldcolumn = "0"
	opts.foldenable = false
	opts.list = false
	opts.wrap = false
	opts.cursorline = true
	opts.winfixwidth = true
end

--- Puts the file and view the panel was opened from back in the target window,
--- then closes any preview and puts the folds and tint back.
---@param closed Panel
local function leave_review(closed)
	local win = closed.target_win
	if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(closed.origin_buf) then
		vim.api.nvim_win_set_buf(win, closed.origin_buf)
		vim.api.nvim_win_call(win, function()
			vim.fn.winrestview(closed.origin_view)
		end)
		vim.api.nvim_set_current_win(win)
	end
	close_unused_preview(closed.preview_buf)
	folds.release_all()
	vim.api.nvim_clear_autocmds({ group = edits_group })
	for buf in pairs(closed.bases) do
		if vim.api.nvim_buf_is_valid(buf) then
			tint.clear(buf)
		end
	end
	-- Only the files as they are now were compared through gitsigns' base.
	if closed.since and not changes.shows_copies(closed.since) then
		gitsigns_base.set(nil, function() end)
	end
end

---@return integer
local function create_panel_buffer()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "Git changes")
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "gitchanges"
	vim.bo[buf].modifiable = false

	vim.keymap.set("n", "<CR>", open_file_under_cursor, { buffer = buf, desc = "Git open the changed file" })
	vim.api.nvim_create_autocmd("BufEnter", {
		desc = "Relist changes on returning to the panel, since staging or committing elsewhere changes them",
		buffer = buf,
		callback = refresh,
	})
	vim.api.nvim_create_autocmd("CursorMoved", {
		desc = "Preview the file under the cursor",
		buffer = buf,
		-- Without it, opening the file skips its BufRead autocmds: no filetype, no gitsigns.
		nested = true,
		callback = function()
			show_file_under_cursor()
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		desc = "Return to where the panel was opened from, however it was closed",
		buffer = buf,
		callback = function()
			local closed = panel
			panel = nil
			-- Switching buffers in other windows is not safe while this one is being wiped.
			vim.schedule(function()
				if closed then
					leave_review(closed)
				end
			end)
		end,
	})
	return buf
end

---@param root string
---@param since Since?
---@param focus_path string? the file to start on, when it is in the list
local function open_panel(root, since, focus_path)
	local files = changes.list(root, since)
	if not files then
		return
	end
	if #files == 0 then
		vim.notify(since and "No changes since " .. since.summary or "No changes")
		return
	end

	local origin_win = vim.api.nvim_get_current_win()
	local origin_buf = vim.api.nvim_get_current_buf()
	local origin_view = vim.fn.winsaveview()
	local buf = create_panel_buffer()
	local width = render.width(render.content(files, changes.title_of(since)))
	local win = vim.api.nvim_open_win(buf, true, { split = "left", win = -1, width = width })
	set_panel_window_options(win)
	panel = {
		buf = buf,
		win = win,
		root = root,
		width = width,
		target_win = origin_win,
		files_by_line = {},
		origin_buf = origin_buf,
		origin_view = origin_view,
		since = since,
		ready = false,
		bases = {},
	}
	draw(files)
	if focus_path then
		vim.api.nvim_win_set_cursor(win, { render.line_of(panel.files_by_line, focus_path) or 1, 0 })
	end
	local opened = panel
	if changes.shows_copies(since) then
		opened.ready = true
		show_file_under_cursor()
		return
	end
	gitsigns_base.set(since and since.commit, function()
		if panel == opened then
			opened.ready = true
			show_file_under_cursor()
		end
	end)
end

--- Leaves the review straight away, where the wipe handler would only schedule
--- it, so a panel opened next does not have its tint undone. As the last window
--- the panel cannot close, so it gives way to an empty buffer instead.
local function close_panel()
	assert(panel, "close_panel needs an open panel")
	local closed = panel
	panel = nil
	local normal_wins = vim.tbl_filter(function(win)
		return vim.api.nvim_win_get_config(win).relative == ""
	end, vim.api.nvim_tabpage_list_wins(0))
	if #normal_wins == 1 and normal_wins[1] == closed.win then
		vim.api.nvim_win_set_buf(closed.win, vim.api.nvim_create_buf(true, false))
	else
		vim.api.nvim_win_close(closed.win, false)
	end
	leave_review(closed)
end

function M.toggle()
	if panel and vim.api.nvim_win_is_valid(panel.win) then
		close_panel()
		return
	end
	local root = git.current_root()
	if root then
		open_panel(root, nil)
	end
end

--- Opens the panel on since, replacing a panel already open.
---@param root string
---@param since Since
---@param focus_path string?
function M.replace(root, since, focus_path)
	if panel and vim.api.nvim_win_is_valid(panel.win) then
		close_panel()
	end
	open_panel(root, since, focus_path)
end

local group = vim.api.nvim_create_augroup("git-changes-panel", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
	desc = "Relist changes in the open panel after a save",
	group = group,
	callback = refresh,
})

vim.api.nvim_create_autocmd("BufEnter", {
	desc = "Keep a previewed file open once it is entered, with <CR> or by moving to its window",
	group = group,
	callback = function(ev)
		if panel and ev.buf == panel.preview_buf and vim.api.nvim_get_current_win() ~= panel.win then
			panel.preview_buf = nil
		end
	end,
})

return M
