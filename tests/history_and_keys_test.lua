--- Line history over a real repo, the keymap picker's grouping, and the live grep pickers.

local h = require("helpers")

---@param root string
---@param ... string
local function git(root, ...)
	local result = vim.system({ "git", ... }, { cwd = root, text = true }):wait()
	assert(result.code == 0, result.stderr)
	return vim.trim(result.stdout)
end

--- Three commits: `first` makes a.lua, `second` changes alpha's body, `third` beta's.
---@return string root
local function repo()
	local root = h.temp_dir()
	git(root, "init", "-q", "-b", "main")
	git(root, "config", "user.name", "Test")
	git(root, "config", "user.email", "test@example.com")
	local function commit(lines, message)
		vim.fn.writefile(lines, root .. "/a.lua")
		git(root, "add", "-A")
		git(root, "commit", "-qm", message)
	end
	commit({ "local function alpha()", "  return 1", "end", "", "local function beta()", "  return 1", "end" }, "first")
	commit(
		{ "local function alpha()", "  return 2", "end", "", "local function beta()", "  return 1", "end" },
		"second"
	)
	commit({ "local function alpha()", "  return 2", "end", "", "local function beta()", "  return 3", "end" }, "third")
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/a.lua")
	vim.bo.filetype = "lua"
	return root
end

---@return table[] the pickers opened
local function stub_commit_picker()
	local picked = {}
	local commits = require("plugins.editor.git_changes.commits")
	---@diagnostic disable-next-line: duplicate-set-field
	commits.pick = function(title, rows_for, preview_command, on_pick)
		table.insert(picked, {
			title = title,
			rows = rows_for(false),
			preview_command = preview_command,
			on_pick = on_pick,
		})
	end
	return picked
end

local function line_history()
	return require("plugins.editor.git_changes.line_history")
end

local function subjects(rows)
	return vim.tbl_map(function(row)
		return row.subject
	end, rows)
end

local tests = {}

function tests.selected_lines_list_only_the_commits_that_changed_them()
	repo()
	local picked = stub_commit_picker()
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.cmd.normal({ "V", bang = true })

	line_history().pick_selection(function() end)

	h.assert_equal(picked[1].title, "History of lines 2-2", "title")
	h.assert_equal(subjects(picked[1].rows), { "second", "first" }, "commits")
end

function tests.a_selection_made_upward_is_the_same_range()
	repo()
	local picked = stub_commit_picker()
	vim.api.nvim_win_set_cursor(0, { 6, 0 })
	vim.cmd.normal({ "V", bang = true })
	vim.cmd.normal({ "k", bang = true })

	line_history().pick_selection(function() end)

	h.assert_equal(picked[1].title, "History of lines 5-6", "title")
	h.assert_equal(subjects(picked[1].rows), { "third", "first" }, "commits")
end

function tests.uncommitted_lines_above_do_not_move_the_range_onto_other_code()
	repo()
	local picked = stub_commit_picker()
	vim.api.nvim_buf_set_lines(0, 0, 0, false, { "-- new", "-- new", "-- new", "-- new" })
	vim.api.nvim_win_set_cursor(0, { 10, 0 })
	vim.cmd.normal({ "V", bang = true })

	line_history().pick_selection(function() end)

	h.assert_equal(subjects(picked[1].rows), { "third", "first" }, "commits of the line now at 10")
end

function tests.lines_never_committed_say_so()
	repo()
	local notified = h.capture_notifications()
	local picked = stub_commit_picker()
	vim.api.nvim_buf_set_lines(0, 0, 0, false, { "-- new" })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
	vim.cmd.normal({ "V", bang = true })

	line_history().pick_selection(function() end)

	h.assert_contains(notified, "have not been committed yet", "message")
	h.assert_equal(#picked, 0, "pickers")
end

function tests.an_untracked_file_has_no_history()
	local root = repo()
	local notified = h.capture_notifications()
	stub_commit_picker()
	vim.fn.writefile({ "new" }, root .. "/b.lua")
	vim.cmd.edit(root .. "/b.lua")
	vim.cmd.normal({ "V", bang = true })

	line_history().pick_selection(function() end)

	h.assert_contains(notified, "have not been committed yet", "message")
end

function tests.a_buffer_that_is_no_file_has_no_history()
	repo()
	local notified = h.capture_notifications()
	vim.cmd.enew()
	vim.bo.buftype = "nofile"
	vim.cmd.normal({ "V", bang = true })

	line_history().pick_selection(function() end)

	h.assert_contains(notified, "needs a file in this repository", "message")
end

function tests.the_function_under_the_cursor_lists_its_own_history()
	repo()
	local picked = stub_commit_picker()
	vim.api.nvim_win_set_cursor(0, { 6, 0 })

	line_history().pick_function(function() end)

	h.assert_equal(picked[1].title, "History of local function beta()", "title")
	h.assert_equal(subjects(picked[1].rows), { "third", "first" }, "commits")
end

function tests.outside_any_function_says_to_select_lines()
	repo()
	local notified = h.capture_notifications()
	vim.api.nvim_win_set_cursor(0, { 4, 0 })

	line_history().pick_function(function() end)

	h.assert_contains(notified, "No function under the cursor", "message")
end

function tests.a_commit_previews_as_its_change_to_those_lines()
	local root = repo()
	local picked = stub_commit_picker()
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.cmd.normal({ "V", bang = true })
	line_history().pick_selection(function() end)

	local command = picked[1].preview_command(picked[1].rows[2].commit)

	h.assert_equal(command, { "git", "-C", root, "log", "-L", "2,2:a.lua", "--skip=1", "-n1" }, "command")
end

function tests.picking_a_commit_opens_it_at_this_file()
	local root = repo()
	local picked = stub_commit_picker()
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.cmd.normal({ "V", bang = true })
	local opened
	line_history().pick_selection(function(...)
		opened = { ... }
	end)

	picked[1].on_pick(picked[1].rows[1])

	h.assert_equal(opened, { root, picked[1].rows[1].commit, "a.lua" }, "opened")
end

function tests.commit_rows_can_be_only_your_own()
	local root = repo()
	git(root, "-c", "user.email=other@example.com", "commit", "-q", "--allow-empty", "-m", "theirs")
	local commits = require("plugins.editor.git_changes.commits")

	h.assert_equal(commits.rows(root, nil, false)[1].subject, "theirs", "everyone's")
	h.assert_equal(commits.rows(root, nil, true)[1].subject, "third", "yours")
	h.assert_equal(commits.rows(root, "HEAD~2..HEAD", false)[2].subject, "third", "a range")
end

local function collect(show_unlabelled)
	return require("plugins.editor.telescope.keymaps").collect(show_unlabelled or false)
end

local function row_for(rows, keys)
	for _, row in ipairs(rows) do
		if row.keys == keys then
			return row
		end
	end
	error("no row for " .. keys)
end

function tests.each_key_is_grouped_by_what_its_sequence_means()
	vim.keymap.set("n", " gx", "<Nop>", { desc = "leader key" })
	vim.keymap.set("n", "]z", "<Nop>", { desc = "bracket" })
	vim.keymap.set("x", "az", "<Nop>", { desc = "textobject" })
	vim.keymap.set("n", "<C-w>z", "<Nop>", { desc = "window" })
	vim.keymap.set("n", ",z", "<Nop>", { desc = "localleader" })
	vim.keymap.set("n", "J", "<Nop>", { desc = "named key" })
	vim.keymap.set("n", "Zz", "<Nop>", { desc = "unknown" })

	local rows = collect()

	h.assert_equal(row_for(rows, " gx").domain, "Git", "leader domain")
	h.assert_equal(row_for(rows, " gx").lhs, "<leader>gx", "written with leader")
	h.assert_equal(row_for(rows, "]z").domain, "Motion", "bracket")
	h.assert_equal(row_for(rows, "az").domain, "Textobject", "textobject")
	h.assert_equal(row_for(rows, "<C-W>z").domain, "Window", "window")
	h.assert_equal(row_for(rows, ",z").domain, "Replace", "localleader")
	h.assert_equal(row_for(rows, "J").domain, "Editing", "named key")
	h.assert_equal(row_for(rows, "Zz").domain, "Other", "unknown")
end

function tests.a_mapping_in_several_modes_is_one_row()
	vim.keymap.set({ "n", "x" }, "Zq", "<Nop>", { desc = "both" })

	h.assert_equal(row_for(collect(), "Zq").modes, "nx", "modes")
end

function tests.a_key_can_mean_something_else_in_another_mode()
	vim.keymap.set("i", "<C-U>", "<Nop>", { desc = "delete" })

	h.assert_equal(row_for(collect(), "<C-U>").domain, "Editing", "insert mode")
end

function tests.unlabelled_mappings_show_only_when_asked()
	vim.keymap.set("n", "Zr", ":echo 1<CR>")
	vim.keymap.set("n", "Zf", function() end)

	h.assert_equal(pcall(row_for, collect(), "Zr"), false, "hidden")
	local rows = collect(true)
	h.assert_equal(row_for(rows, "Zr").desc, ":echo 1<CR>", "right hand side")
	h.assert_contains({ row_for(rows, "Zf").desc }, "history_and_keys_test.lua", "where the function is")
end

function tests.rows_sort_by_domain_then_key()
	local rows = collect(true)
	for index = 2, #rows do
		local before, after = rows[index - 1], rows[index]
		h.assert_equal(before.domain <= after.domain, true, "domains in order at " .. index)
	end
end

---@return table[] finders passed to telescope
local function stub_live_picker()
	local opened = {}
	package.loaded["telescope.pickers"] = {
		new = function(_, spec)
			return {
				find = function()
					table.insert(opened, spec)
				end,
			}
		end,
	}
	package.loaded["telescope.finders"] = {
		new_job = function(command_for)
			return command_for
		end,
	}
	package.loaded["telescope.config"] = { values = { grep_previewer = function() end } }
	package.loaded["telescope.make_entry"] = { gen_from_vimgrep = function() end }
	package.loaded["telescope.sorters"] = { highlighter_only = function() end }
	return opened
end

function tests.live_grep_splits_globs_off_the_pattern()
	local opened = stub_live_picker()

	require("plugins.editor.telescope.grep").grep_with_glob_filter()

	local command_for = opened[1].finder
	h.assert_equal(
		command_for("needle  *.lua"),
		{ "rg", "--vimgrep", "--smart-case", "--glob", "*.lua", "--", "needle" },
		"command"
	)
	h.assert_equal(command_for(""), nil, "empty prompt")
	h.assert_equal(command_for("  *.lua"), nil, "globs but no pattern yet")
end

function tests.grepping_changed_files_covers_modified_and_untracked_only()
	local root = repo()
	vim.fn.writefile({ "changed" }, root .. "/a.lua")
	vim.fn.writefile({ "new" }, root .. "/b.lua")
	local opened = stub_live_picker()

	require("plugins.editor.telescope.grep").grep_changed_files()

	h.assert_equal(opened[1].finder("x"), { "rg", "--vimgrep", "--smart-case", "--", "x", "a.lua", "b.lua" }, "command")
end

function tests.grepping_changed_files_says_when_there_are_none_or_git_fails()
	repo()
	local notified = h.capture_notifications()
	local opened = stub_live_picker()
	local grep = require("plugins.editor.telescope.grep")

	grep.grep_changed_files()
	h.assert_contains(notified, "No changed files", "clean tree")

	vim.cmd.cd(h.temp_dir())
	grep.grep_changed_files()
	h.assert_contains(notified, "git failed", "outside a repo")
	h.assert_equal(#opened, 0, "pickers")
end

return tests
