--- Merge conflicts: reading their markers, and the keys that step through and settle them.

local h = require("helpers")

local TWO_CONFLICTS = {
	"before",
	"<<<<<<< HEAD",
	"ours one",
	"=======",
	"theirs one",
	">>>>>>> topic",
	"between",
	"<<<<<<< HEAD",
	"ours two",
	"=======",
	"theirs two",
	">>>>>>> topic",
	"after",
}

---@param lines string[]
---@return table the module, with its keys set
local function buffer_with(lines)
	local conflicts = require("plugins.editor.conflicts")
	vim.api.nvim_buf_set_lines(0, 0, -1, true, lines)
	return conflicts
end

local function line()
	return vim.fn.line(".")
end

local function lines()
	return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

---@param root string
---@param ... string
---@return vim.SystemCompleted
local function git(root, ...)
	return vim.system({ "git", "-c", "user.name=T", "-c", "user.email=t@t", "-C", root, ... }, { text = true }):wait()
end

--- A repo stopped on a real conflict in f.txt.
---@param style string merge.conflictStyle
---@return string root
local function repo_in_conflict(style)
	local root = h.temp_dir()
	local file = vim.fs.joinpath(root, "f.txt")
	git(root, "init", "-q", "-b", "main")
	git(root, "config", "merge.conflictStyle", style)
	vim.fn.writefile({ "top", "base", "bottom" }, file)
	git(root, "add", "f.txt")
	git(root, "commit", "-qm", "base")
	git(root, "switch", "-qc", "topic")
	vim.fn.writefile({ "top", "theirs", "bottom" }, file)
	git(root, "commit", "-qam", "theirs")
	git(root, "switch", "-q", "main")
	vim.fn.writefile({ "top", "ours", "bottom" }, file)
	git(root, "commit", "-qam", "ours")
	h.assert_equal(git(root, "merge", "topic").code, 1, "merge stops on the conflict")
	return root
end

local tests = {}

function tests.parse_finds_each_conflict_s_markers()
	local parsed = buffer_with({}).parse(TWO_CONFLICTS)

	h.assert_equal(parsed, {
		{ start = 2, separator = 4, finish = 6 },
		{ start = 8, separator = 10, finish = 12 },
	}, "conflicts")
end

function tests.parse_notes_the_base_section_of_diff3()
	local parsed = buffer_with({}).parse({ "<<<<<<< a", "ours", "||||||| b", "base", "=======", "theirs", ">>>>>>> c" })

	h.assert_equal(parsed, { { start = 1, base = 3, separator = 5, finish = 7 } }, "conflict")
end

function tests.parse_skips_a_conflict_missing_a_marker()
	local conflicts = buffer_with({})

	h.assert_equal(conflicts.parse({ "<<<<<<< a", "ours", "=======", "theirs" }), {}, "no end")
	h.assert_equal(conflicts.parse({ "<<<<<<< a", "ours", ">>>>>>> c" }), {}, "no separator")
end

function tests.parse_starts_again_at_a_second_opening_marker()
	local parsed = buffer_with({}).parse({ "<<<<<<< a", "<<<<<<< a", "=======", ">>>>>>> c" })

	h.assert_equal(parsed, { { start = 2, separator = 3, finish = 4 } }, "conflict")
end

function tests.parse_ignores_what_only_looks_like_a_marker()
	local parsed = buffer_with({}).parse({
		"Heading",
		"=======",
		"<<<<<<<<< nested",
		"<<<<<<<x",
		"=========",
		">>>>>>> stray",
	})

	h.assert_equal(parsed, {}, "conflicts")
end

function tests.a_plain_separator_inside_ours_ends_ours_but_a_longer_one_does_not()
	local parsed = buffer_with({}).parse({ "<<<<<<< a", "=========", "=======", ">>>>>>> c" })

	h.assert_equal(parsed, { { start = 1, separator = 3, finish = 4 } }, "conflict")
end

function tests.keeping_ours_leaves_our_lines_and_the_cursor_on_them()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 3, 0 })

	h.press("<leader>go")

	h.assert_equal(lines()[2], "ours one", "kept line")
	h.assert_equal(#lines(), 9, "lines left")
	h.assert_equal(lines()[3], "between", "the rest")
	h.assert_equal(line(), 2, "cursor")
end

function tests.keeping_theirs_leaves_their_lines()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 9, 0 })

	h.press("<leader>gt")

	h.assert_equal(lines()[8], "theirs two", "kept line")
	h.assert_equal(lines()[9], "after", "the rest")
	h.assert_equal(lines()[2], "<<<<<<< HEAD", "the other conflict")
end

function tests.keeping_both_puts_ours_before_theirs()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 6, 0 })

	h.press("<leader>ga")

	h.assert_equal(vim.list_slice(lines(), 1, 4), { "before", "ours one", "theirs one", "between" }, "lines")
end

function tests.a_key_works_from_either_marker_line()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	h.press("<leader>go")
	h.assert_equal(lines()[2], "ours one", "from the opening marker")

	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 6, 0 })
	h.press("<leader>go")
	h.assert_equal(lines()[2], "ours one", "from the closing marker")
end

function tests.keeping_a_side_drops_the_base_section()
	buffer_with({ "<<<<<<< a", "ours", "||||||| b", "base", "=======", "theirs", ">>>>>>> c" })

	h.press("<leader>go")

	h.assert_equal(lines(), { "ours" }, "lines")
end

function tests.keeping_both_drops_the_base_section()
	buffer_with({ "<<<<<<< a", "ours", "||||||| b", "base", "=======", "theirs", ">>>>>>> c" })

	h.press("<leader>ga")

	h.assert_equal(lines(), { "ours", "theirs" }, "lines")
end

function tests.keeping_an_empty_side_at_the_end_of_the_file_leaves_the_cursor_valid()
	buffer_with({ "top", "<<<<<<< a", "=======", "theirs", ">>>>>>> c" })
	vim.api.nvim_win_set_cursor(0, { 2, 0 })

	h.press("<leader>go")

	h.assert_equal(lines(), { "top" }, "lines")
	h.assert_equal(line(), 1, "cursor")
end

function tests.a_pick_undoes_in_one_step()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 3, 0 })
	vim.cmd("let &undolevels = &undolevels")

	h.press("<leader>go")
	vim.cmd.undo()

	h.assert_equal(lines(), TWO_CONFLICTS, "lines")
end

function tests.a_pick_away_from_any_conflict_changes_nothing_and_says_so()
	buffer_with(TWO_CONFLICTS)
	local notified = h.capture_notifications()
	vim.api.nvim_win_set_cursor(0, { 7, 0 })

	h.press("<leader>go")

	h.assert_equal(lines(), TWO_CONFLICTS, "lines")
	h.assert_contains(notified, "No conflict under the cursor", "message")
end

function tests.the_motions_step_between_conflicts_and_wrap()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	h.press("]n")
	h.assert_equal(line(), 2, "first")
	h.press("]n")
	h.assert_equal(line(), 8, "second")
	h.press("]n")
	h.assert_equal(line(), 2, "wrapped forward")
	h.press("[n")
	h.assert_equal(line(), 8, "wrapped back")
	h.press("[n")
	h.assert_equal(line(), 2, "back")
end

function tests.going_back_from_inside_a_conflict_lands_on_its_start()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 10, 0 })

	h.press("[n")

	h.assert_equal(line(), 8, "cursor")
end

function tests.the_motions_take_a_count()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	vim.cmd.normal("2]n")

	h.assert_equal(line(), 8, "cursor")
end

function tests.a_jump_can_be_undone_with_the_jump_list()
	buffer_with(TWO_CONFLICTS)
	vim.api.nvim_win_set_cursor(0, { 7, 0 })

	h.press("]n")
	vim.cmd.normal({ "``", bang = true })

	h.assert_equal(line(), 7, "cursor")
end

function tests.the_motions_say_when_there_are_no_conflicts()
	buffer_with({ "clean" })
	local notified = h.capture_notifications()

	h.press("]n")

	h.assert_contains(notified, "No conflicts in this file", "message")
	h.assert_equal(line(), 1, "cursor")
end

function tests.settles_a_real_git_conflict_in_each_style()
	for _, style in ipairs({ "merge", "diff3", "zdiff3" }) do
		local root = repo_in_conflict(style)
		local file = vim.fs.joinpath(root, "f.txt")
		require("plugins.editor.conflicts")
		vim.cmd.edit({ file, bang = true })

		h.press("]n")
		h.press("<leader>gt")
		vim.cmd("silent write!")

		h.assert_equal(vim.fn.readfile(file), { "top", "theirs", "bottom" }, style)
		vim.cmd.bwipeout({ bang = true })
	end
end

return tests
