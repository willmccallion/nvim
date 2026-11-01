--- The changed files panel, driven through its command and keys in a throwaway repo.

local TIMEOUT_MS = 5000

local h = require("helpers")
local assert_equal, assert_contains, refute_contains = h.assert_equal, h.assert_contains, h.refute_contains
local capture_notifications, press = h.capture_notifications, h.press

local function fail(message)
	error(message, 2)
end

---@param condition fun(): any
---@param what string
local function wait_for(condition, what)
	if not vim.wait(TIMEOUT_MS, condition, 10) then
		fail("timed out waiting for " .. what)
	end
end

---@param root string
---@param ... string
---@return string
local function git(root, ...)
	local result = vim.system({ "git", ... }, { cwd = root, text = true }):wait()
	if result.code ~= 0 then
		error(("git %s: %s"):format(table.concat({ ... }, " "), result.stderr))
	end
	return vim.trim(result.stdout)
end

---@param root string
---@param path string
---@param lines string[]
local function write(root, path, lines)
	local full = vim.fs.joinpath(root, path)
	vim.fn.mkdir(vim.fs.dirname(full), "p")
	vim.fn.writefile(lines, full)
end

local ORIGINAL = { "one", "two", "three", "four", "five", "six", "seven", "eight" }
local EDITED = { "one", "two", "THREE", "four", "five", "six", "seven", "eight" }

--- A repo with two commits and a.txt open: `first` made every file, `second`
--- changed a.txt's third line. The working tree matches `second`.
---@return string root
local function repo()
	local root = vim.fn.tempname()
	vim.fn.mkdir(root, "p")
	git(root, "init", "-q", "-b", "main")
	git(root, "config", "user.name", "Test")
	git(root, "config", "user.email", "test@example.com")
	write(root, "a.txt", ORIGINAL)
	write(root, "gone.txt", { "going away" })
	write(root, "old_name.txt", { "keeps", "its", "words", "when", "renamed" })
	write(root, "lib/b.txt", { "in a folder" })
	git(root, "add", "-A")
	git(root, "commit", "-qm", "first")
	write(root, "a.txt", EDITED)
	git(root, "commit", "-qam", "second")

	vim.cmd.cd(root)
	vim.cmd.edit(vim.fs.joinpath(root, "a.txt"))
	require("gitsigns").setup({})
	return root
end

---@return integer?
local function panel_buf()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "gitchanges" then
			return buf
		end
	end
	return nil
end

---@return string[]
local function panel_lines()
	return vim.api.nvim_buf_get_lines(assert(panel_buf(), "no panel is open"), 0, -1, false)
end

---@return integer
local function panel_win()
	local buf = assert(panel_buf(), "no panel is open")
	return vim.fn.win_findbuf(buf)[1]
end

--- The window beside the panel, where files preview.
---@return integer
local function preview_win()
	local panel = panel_win()
	for _, win in ipairs(vim.api.nvim_tabpage_list_wins(0)) do
		if win ~= panel then
			return win
		end
	end
	fail("nothing beside the panel")
	return panel
end

---@return integer
local function preview_buf()
	return vim.api.nvim_win_get_buf(preview_win())
end

---@param buf integer
---@return vim.api.keyset.get_extmark_item[]
local function tint_marks(buf)
	local ns = vim.api.nvim_get_namespaces()["git-changes-tint"]
	return vim.api.nvim_buf_get_extmarks(buf, ns, 0, -1, { details = true })
end

---@param buf integer
---@return string[] the removed lines the tint draws above the new ones
local function removed_lines_shown(buf)
	local shown = {}
	for _, mark in ipairs(tint_marks(buf)) do
		for _, chunks in ipairs(mark[4].virt_lines or {}) do
			local text = {}
			for i = 1, #chunks - 1 do
				table.insert(text, chunks[i][1])
			end
			table.insert(shown, table.concat(text))
		end
	end
	return shown
end

---@param file string the end of a panel line
local function select_file(file)
	for line, text in ipairs(panel_lines()) do
		if vim.endswith(text, " " .. file) then
			vim.api.nvim_win_set_cursor(panel_win(), { line, 0 })
			vim.api.nvim_exec_autocmds("CursorMoved", { buffer = panel_buf() })
			return
		end
	end
	fail(("no %s in %s"):format(file, vim.inspect(panel_lines())))
end

local function wait_for_preview()
	wait_for(function()
		return panel_buf() and #vim.api.nvim_tabpage_list_wins(0) > 1 and #tint_marks(preview_buf()) > 0
	end, "a tinted preview")
end

---@param lines_of_pick table[] filled with what each picker offered
---@param choose fun(rows: table[], title: string): table the row to pick
local function stub_picker(lines_of_pick, choose)
	require("plugins.editor.git_changes")
	local commits = require("plugins.editor.git_changes.commits")
	---@diagnostic disable-next-line: duplicate-set-field
	commits.pick = function(title, rows_for, preview_command, on_pick)
		local rows = rows_for(false)
		table.insert(lines_of_pick, { title = title, rows = rows, preview_command = preview_command })
		on_pick(choose(rows, title))
	end
end

local tests = {}

function tests.lists_uncommitted_changes_with_folders_after_root_files()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", ORIGINAL)
	write(root, "new.txt", { "brand new" })
	write(root, "lib/b.txt", { "changed" })
	press("<leader>gd")
	assert_equal(
		vim.tbl_map(function(line)
			return (line:gsub("^(%s*%S+) %S+ ", "%1 "))
		end, panel_lines()),
		{ "M a.txt", "? new.txt", "lib/", "  M b.txt" },
		"panel lines"
	)
end

function tests.previews_a_change_with_the_removed_line_above_the_new_one()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "one", "two", "3", "four", "five", "six", "seven", "eight" })
	press("<leader>gd")
	wait_for_preview()
	assert_equal(vim.api.nvim_buf_get_name(preview_buf()), vim.fs.joinpath(root, "a.txt"), "previewed file")
	assert_equal(removed_lines_shown(preview_buf()), { "THREE" }, "removed lines")
	assert_equal(vim.api.nvim_win_get_cursor(preview_win())[1], 3, "cursor on the first change")
	local removed = vim.tbl_filter(function(mark)
		return mark[4].virt_lines ~= nil
	end, tint_marks(preview_buf()))
	assert_equal(removed[1][4].virt_lines_above, true, "removed line sits above the new one")
end

function tests.a_change_marks_only_the_part_of_the_line_that_differs()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "one", "two", "THxEE", "four", "five", "six", "seven", "eight" })
	press("<leader>gd")
	wait_for_preview()
	local inline = vim.tbl_filter(function(mark)
		return mark[4].hl_group == "GitSignsAddInline"
	end, tint_marks(preview_buf()))
	assert_equal(#inline, 1, "inline marks")
	assert_equal({ inline[1][3], inline[1][4].end_col }, { 2, 3 }, "marked columns")
end

function tests.filling_in_a_stub_marks_only_the_brace_that_went_away()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "stub.cpp", {
		"#include <x>",
		"// TODO: Due by part 1",
		"void PassCodeGen::operator()(ast::FunctionCall &node) {}",
		"int after;",
	})
	git(root, "add", "-A")
	git(root, "commit", "-qm", "stub")
	write(root, "stub.cpp", {
		"#include <x>",
		"void PassCodeGen::operator()(ast::FunctionCall &node) {",
		"  emitCall(node.name, node.funcParams);",
		"}",
		"int after;",
	})
	press("<leader>gd")
	wait_for_preview()
	local marked_new, marked_old = {}, {}
	for _, mark in ipairs(tint_marks(preview_buf())) do
		if mark[4].hl_group == "GitSignsAddInline" then
			table.insert(marked_new, mark[2])
		end
		for _, chunks in ipairs(mark[4].virt_lines or {}) do
			for _, chunk in ipairs(chunks) do
				if chunk[2] == "GitSignsDeleteVirtLnInLine" and chunk[1] ~= "" then
					table.insert(marked_old, chunk[1])
				end
			end
		end
	end
	assert_equal(marked_new, {}, "nothing was added to the signature")
	assert_equal(marked_old, { "}" }, "only the brace is marked as removed")
end

function tests.a_preview_folds_away_lines_far_from_the_change_until_closed()
	local root = repo()
	require("plugins.editor.git_changes")
	local long = {}
	for line = 1, 40 do
		long[line] = "line " .. line
	end
	write(root, "a.txt", long)
	git(root, "commit", "-qam", "long")
	long[2] = "changed"
	write(root, "a.txt", long)
	vim.cmd.edit({ bang = true })
	press("<leader>gd")
	wait_for_preview()
	local win = preview_win()
	local closed_at_end = function()
		return vim.api.nvim_win_call(win, function()
			return vim.fn.foldclosed(30) ~= -1
		end)
	end
	assert_equal(closed_at_end(), true, "far lines folded in the review")
	press("<leader>gd")
	assert_equal(closed_at_end(), false, "folds gone after closing")
end

function tests.previews_a_deleted_file_from_git()
	local root = repo()
	require("plugins.editor.git_changes")
	vim.fn.delete(vim.fs.joinpath(root, "gone.txt"))
	press("<leader>gd")
	wait_for(function()
		return panel_buf() and vim.api.nvim_buf_get_name(preview_buf()) == "git-deleted://gone.txt"
	end, "the deleted file's preview")
	assert_equal(vim.api.nvim_buf_get_lines(preview_buf(), 0, -1, false), { "going away" }, "preview text")
	assert_equal(vim.bo[preview_buf()].modifiable, false, "read-only")
end

function tests.tints_a_real_file_again_as_it_is_edited()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "one", "two", "3", "four", "five", "six", "seven", "eight" })
	press("<leader>gd")
	wait_for_preview()
	local buf = preview_buf()
	vim.api.nvim_buf_set_lines(buf, 0, 1, false, { "ONE" })
	vim.api.nvim_exec_autocmds("TextChanged", { buffer = buf })
	assert_equal(removed_lines_shown(buf), { "one", "THREE" }, "removed lines after the edit")
end

function tests.keeps_a_preview_of_a_previewed_file_only_while_it_shows()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "changed" })
	write(root, "new.txt", { "brand new" })
	press("<leader>gd")
	wait_for_preview()
	select_file("new.txt")
	local new_buf = preview_buf()
	assert_equal(vim.api.nvim_buf_get_name(new_buf), vim.fs.joinpath(root, "new.txt"), "second preview")
	select_file("a.txt")
	assert_equal(vim.api.nvim_buf_is_valid(new_buf), false, "unused preview closed")
end

function tests.keeps_a_previewed_file_open_once_it_is_entered()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "changed" })
	write(root, "new.txt", { "brand new" })
	press("<leader>gd")
	wait_for_preview()
	select_file("new.txt")
	local new_buf = preview_buf()
	vim.api.nvim_set_current_win(panel_win())
	press("<CR>")
	assert_equal(vim.api.nvim_get_current_buf(), new_buf, "<CR> moved into the file")
	select_file("a.txt")
	assert_equal(vim.api.nvim_buf_is_valid(new_buf), true, "entered file stays open")
end

function tests.closing_returns_to_the_file_and_clears_the_review()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "new.txt", { "brand new" })
	write(root, "a.txt", { "changed" })
	vim.cmd.edit(vim.fs.joinpath(root, "lib/b.txt"))
	local origin = vim.api.nvim_get_current_buf()
	press("<leader>gd")
	wait_for_preview()
	local previewed = preview_buf()
	press("<leader>gd")
	assert_equal(panel_buf(), nil, "panel closed")
	assert_equal(vim.api.nvim_get_current_buf(), origin, "back on the original file")
	assert_equal(#tint_marks(previewed), 0, "tint cleared")
end

function tests.changes_since_a_commit_list_committed_and_untracked_files()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "new.txt", { "brand new" })
	vim.cmd.GitChanges("HEAD~1")
	wait_for_preview()
	local lines = panel_lines()
	assert_contains(lines, "since " .. git(root, "rev-parse", "--short", "HEAD~1") .. " first", "title")
	assert_contains(lines, "a.txt", "committed change")
	assert_contains(lines, "new.txt", "untracked file")
	assert_equal(removed_lines_shown(preview_buf()), { "three" }, "tint against that commit")
	wait_for(function()
		return require("gitsigns.config").config.base == git(root, "rev-parse", "--short", "HEAD~1")
	end, "gitsigns' base to follow the panel")
	press("<leader>gd")
	wait_for(function()
		return require("gitsigns.config").config.base == nil
	end, "gitsigns' base to go back")
end

function tests.a_commit_range_previews_read_only_copies_with_hunk_keys()
	local root = repo()
	require("plugins.editor.git_changes")
	local older, newer = git(root, "rev-parse", "--short", "HEAD~1"), git(root, "rev-parse", "--short", "HEAD")
	write(root, "a.txt", { "the working tree must not show" })
	vim.cmd.GitChanges({ args = { older, newer } })
	wait_for_preview()
	assert_contains(panel_lines(), ("%s → %s"):format(older, newer), "title")
	assert_equal(vim.api.nvim_buf_get_name(preview_buf()), ("git-%s://a.txt"):format(newer), "copy's name")
	assert_equal(vim.api.nvim_buf_get_lines(preview_buf(), 0, -1, false), EDITED, "copy's text")
	assert_equal(vim.bo[preview_buf()].modifiable, false, "read-only")
	assert_equal(removed_lines_shown(preview_buf()), { "three" }, "tint")
	assert_equal(vim.fn.maparg("]h", "n", false, true).buffer, nil, "panel has no hunk keys")
	vim.api.nvim_buf_call(preview_buf(), function()
		assert_equal(vim.fn.maparg("]h", "n", false, true).buffer, 1, "copy has hunk keys")
	end)
	assert_equal(require("gitsigns.config").config.base, nil, "gitsigns' base untouched")
end

function tests.one_commit_shows_only_what_it_changed()
	local root = repo()
	require("plugins.editor.git_changes")
	vim.cmd.GitChanges({ args = { "--commit", "HEAD" } })
	wait_for_preview()
	local lines = panel_lines()
	assert_contains(lines, "a.txt", "changed file")
	refute_contains(lines, "gone.txt", "file from the earlier commit")
	assert_equal(#vim.tbl_keys(lines), 2, "title and one file")
	assert_contains(lines, git(root, "rev-parse", "--short", "HEAD"), "title")
end

function tests.the_first_commit_compares_against_the_empty_tree()
	local root = repo()
	require("plugins.editor.git_changes")
	vim.cmd.GitChanges({ args = { "--commit", "HEAD~1" } })
	wait_for_preview()
	local lines = panel_lines()
	assert_contains(lines, "empty → " .. git(root, "rev-parse", "--short", "HEAD~1"), "title")
	assert_contains(lines, "gone.txt", "every file is new")
end

function tests.staged_changes_preview_the_index_copy()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "one", "two", "staged", "four", "five", "six", "seven", "eight" })
	git(root, "add", "a.txt")
	write(root, "a.txt", { "only in the working tree" })
	vim.cmd.GitChanges("--cached")
	wait_for_preview()
	assert_contains(panel_lines(), git(root, "rev-parse", "--short", "HEAD") .. " → staged", "title")
	assert_equal(vim.api.nvim_buf_get_name(preview_buf()), "git-staged://a.txt", "copy's name")
	assert_equal(vim.api.nvim_buf_get_lines(preview_buf(), 2, 3, false), { "staged" }, "index text")
	assert_equal(removed_lines_shown(preview_buf()), { "THREE" }, "tint")
end

function tests.nothing_staged_says_so_and_leaves_the_open_panel()
	local root = repo()
	require("plugins.editor.git_changes")
	local notified = capture_notifications()
	write(root, "a.txt", { "changed" })
	press("<leader>gd")
	wait_for_preview()
	local open = panel_buf()
	vim.cmd.GitChanges("--cached")
	assert_contains(notified, "Nothing staged", "notification")
	assert_equal(panel_buf(), open, "panel left open")
end

function tests.an_empty_range_says_so_and_leaves_the_open_panel()
	local root = repo()
	require("plugins.editor.git_changes")
	local notified = capture_notifications()
	write(root, "a.txt", { "changed" })
	press("<leader>gd")
	wait_for_preview()
	local open = panel_buf()
	vim.cmd.GitChanges({ args = { "HEAD", "HEAD" } })
	assert_contains(notified, "No changes since", "notification")
	assert_equal(panel_buf(), open, "panel left open")
end

function tests.a_file_name_with_spaces_is_listed_and_previewed_whole()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "with a space.txt", { "new" })
	press("<leader>gd")
	wait_for_preview()
	assert_contains(panel_lines(), "with a space.txt", "row")
	assert_equal(vim.api.nvim_buf_get_name(preview_buf()), vim.fs.joinpath(root, "with a space.txt"), "preview")
end

function tests.a_removed_tab_is_drawn_as_the_spaces_the_buffer_would_show()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "tabbed.txt", { "\tindented", "kept" })
	git(root, "add", "-A")
	git(root, "commit", "-qm", "tabs")
	write(root, "tabbed.txt", { "kept" })
	vim.o.tabstop = 4
	press("<leader>gd")
	wait_for_preview()
	assert_equal(removed_lines_shown(preview_buf()), { "    indented" }, "removed line")
end

function tests.removing_the_first_line_draws_it_above_the_top_of_the_file()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", vim.list_slice(EDITED, 2))
	press("<leader>gd")
	wait_for_preview()
	local mark = tint_marks(preview_buf())[1]
	assert_equal({ mark[2], mark[4].virt_lines_above }, { 0, true }, "row and side")
end

function tests.removing_a_later_line_draws_it_below_the_line_before()
	local root = repo()
	require("plugins.editor.git_changes")
	local without_three = { "one", "two", "four", "five", "six", "seven", "eight" }
	write(root, "a.txt", without_three)
	press("<leader>gd")
	wait_for_preview()
	local mark = tint_marks(preview_buf())[1]
	assert_equal({ mark[2], mark[4].virt_lines_above or false }, { 1, false }, "row and side")
end

function tests.no_changes_says_so_without_opening_a_panel()
	repo()
	require("plugins.editor.git_changes")
	local notified = capture_notifications()
	press("<leader>gd")
	assert_contains(notified, "No changes", "notification")
	assert_equal(panel_buf(), nil, "panel")
end

function tests.nothing_since_a_commit_shows_what_that_commit_changed()
	local root = repo()
	require("plugins.editor.git_changes")
	local notified = capture_notifications()
	vim.cmd.GitChanges("HEAD")
	wait_for_preview()
	assert_contains(notified, "Nothing has changed since", "notification")
	assert_contains(panel_lines(), git(root, "rev-parse", "--short", "HEAD~1") .. " → ", "title")
end

function tests.a_rename_previews_against_the_old_path()
	local root = repo()
	require("plugins.editor.git_changes")
	git(root, "mv", "old_name.txt", "new_name.txt")
	write(root, "new_name.txt", { "keeps", "its", "words", "when", "renamed", "and more" })
	git(root, "add", "-A")
	vim.cmd.GitChanges({ args = { "--cached" } })
	wait_for_preview()
	local lines = panel_lines()
	assert_contains(lines, "new_name.txt", "new name")
	refute_contains(lines, "old_name.txt", "old name")
	assert_equal(vim.api.nvim_buf_get_name(preview_buf()), "git-staged://new_name.txt", "copy's name")
	assert_equal(#tint_marks(preview_buf()), 1, "one added line, not a whole new file")
end

function tests.a_staged_rename_lists_one_file_among_uncommitted_changes()
	local root = repo()
	require("plugins.editor.git_changes")
	git(root, "mv", "old_name.txt", "new_name.txt")
	write(root, "new_name.txt", { "keeps", "its", "words", "when", "renamed", "and more" })
	press("<leader>gd")
	wait_for_preview()
	local lines = panel_lines()
	assert_contains(lines, "new_name.txt", "new name")
	refute_contains(lines, "old_name.txt", "old name")
	assert_equal(#lines, 1, "one row")
	assert_equal(removed_lines_shown(preview_buf()), {}, "compared with the old path, nothing was removed")
end

function tests.saving_a_file_relists_the_changes()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "a.txt", { "changed" })
	press("<leader>gd")
	wait_for_preview()
	write(root, "new.txt", { "appeared" })
	vim.api.nvim_exec_autocmds("BufWritePost", { pattern = "*" })
	assert_contains(panel_lines(), "new.txt", "relisted file")
end

function tests.the_uncommitted_row_opens_the_uncommitted_changes()
	local root = repo()
	local pickers = {}
	stub_picker(pickers, function(rows)
		return rows[1]
	end)
	write(root, "a.txt", { "changed" })
	vim.cmd.GitChanges("--commit")
	assert_equal(pickers[1].rows[1].subject, "<Uncommitted>", "first row")
	assert_equal(pickers[1].rows[1].commit, nil, "row has no commit")
	wait_for_preview()
	refute_contains(panel_lines(), "since", "uncommitted panel has no title")
end

function tests.the_commit_picker_has_no_uncommitted_row_on_a_clean_tree()
	local root = repo()
	local pickers = {}
	stub_picker(pickers, function(rows)
		return rows[1]
	end)
	vim.cmd.GitChanges("--commit")
	assert_equal(pickers[1].rows[1].commit, git(root, "rev-parse", "--short", "HEAD"), "first row")
	assert_equal(#pickers[1].rows, 2, "only the commits")
end

function tests.previews_of_a_commit_and_of_uncommitted_changes_are_different_commands()
	local root = repo()
	local pickers = {}
	stub_picker(pickers, function(rows)
		return rows[1]
	end)
	write(root, "a.txt", { "changed" })
	vim.cmd.GitChanges("--commit")
	assert_equal(pickers[1].preview_command("abc123"), { "git", "-C", root, "show", "abc123" }, "commit preview")
	assert_contains(pickers[1].preview_command(nil), "git -C", "uncommitted preview runs a shell")
end

function tests.picking_two_commits_opens_the_range_between_them()
	local root = repo()
	local older, newer = git(root, "rev-parse", "--short", "HEAD~1"), git(root, "rev-parse", "--short", "HEAD")
	local pickers = {}
	stub_picker(pickers, function(rows, title)
		if title == "Diff Changes Since Commit" then
			return rows[#rows]
		end
		return rows[#rows]
	end)
	vim.cmd.GitChanges()
	assert_equal(pickers[2].rows[1].subject, "Your files as they are now", "first later row")
	wait_for_preview()
	assert_contains(panel_lines(), ("%s → %s"):format(older, newer), "title")
end

function tests.picking_the_newest_commit_skips_the_second_picker()
	local root = repo()
	local pickers = {}
	stub_picker(pickers, function(rows)
		return rows[1]
	end)
	write(root, "a.txt", { "changed" })
	vim.cmd.GitChanges()
	assert_equal(#pickers, 1, "pickers shown")
	wait_for_preview()
	assert_contains(panel_lines(), "since " .. git(root, "rev-parse", "--short", "HEAD"), "title")
end

function tests.opening_a_second_review_replaces_the_first()
	local root = repo()
	require("plugins.editor.git_changes")
	write(root, "new.txt", { "brand new" })
	vim.cmd.GitChanges("HEAD~1")
	wait_for_preview()
	vim.cmd.GitChanges({ args = { "--commit", "HEAD" } })
	wait_for(function()
		return panel_buf() and not vim.tbl_contains(panel_lines(), "new.txt")
	end, "the second panel")
	local panels = vim.tbl_filter(function(buf)
		return vim.api.nvim_buf_is_loaded(buf) and vim.bo[buf].filetype == "gitchanges"
	end, vim.api.nvim_list_bufs())
	assert_equal(#panels, 1, "open panels")
end

return tests
