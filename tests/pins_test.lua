--- Pinned files, driven through their keys in a throwaway project.

local h = require("helpers")

local function project()
	local root = h.temp_dir()
	vim.fn.mkdir(vim.fs.joinpath(root, ".git"), "p")
	vim.fn.mkdir(vim.fs.joinpath(root, "src"), "p")
	for _, name in ipairs({ "a.txt", "b.txt", "src/c.txt", "d.txt", "e.txt" }) do
		vim.fn.writefile({ name }, vim.fs.joinpath(root, name))
	end
	vim.cmd.cd(root)
	require("plugins.editor.pins")
	return root
end

local function edit(root, name)
	vim.cmd.edit(vim.fs.joinpath(root, name))
end

local function current(root)
	return vim.fs.relpath(root, vim.api.nvim_buf_get_name(0))
end

local tests = {}

function tests.pinning_gives_files_numbers_and_keys_open_them()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	edit(root, "src/c.txt")
	h.press("<leader>a")

	h.press("<leader>1")
	h.assert_equal(current(root), "a.txt", "pin 1")
	h.press("<leader>2")
	h.assert_equal(current(root), "src/c.txt", "pin 2")
end

function tests.pinning_a_file_twice_keeps_its_number()
	local root = project()
	local notified = h.capture_notifications()
	edit(root, "a.txt")
	h.press("<leader>a")
	edit(root, "b.txt")
	h.press("<leader>a")
	edit(root, "a.txt")
	h.press("<leader>a")

	h.assert_contains(notified, "Pinned a.txt as 1", "repeat pin")
	h.assert_equal(#notified, 3, "notifications")
	h.refute_contains(notified, "as 3", "a third number")
end

function tests.a_fifth_pin_says_it_has_no_key()
	local root = project()
	local notified = h.capture_notifications()
	for _, name in ipairs({ "a.txt", "b.txt", "src/c.txt", "d.txt" }) do
		edit(root, name)
		h.press("<leader>a")
	end
	h.refute_contains(notified, "<leader>A moves it", "a fourth pin")
	edit(root, "e.txt")
	h.press("<leader>a")

	h.assert_contains(notified, "<leader>A moves it into 1-4", "a fifth pin")
end

function tests.pins_belong_to_their_project()
	local first = project()
	edit(first, "a.txt")
	h.press("<leader>a")
	local second = project()
	edit(second, "b.txt")
	local notified = h.capture_notifications()

	h.press("<leader>1")

	h.assert_contains(notified, "No pin 1 in this project", "other project")
	h.assert_equal(current(second), "b.txt", "stayed put")
end

function tests.only_a_file_can_be_pinned()
	project()
	local notified = h.capture_notifications()

	h.press("<leader>a")

	h.assert_contains(notified, "Only a file can be pinned", "empty buffer")
end

function tests.a_scratch_buffer_cannot_be_pinned()
	local root = project()
	edit(root, "a.txt")
	vim.bo.buftype = "nofile"
	local notified = h.capture_notifications()

	h.press("<leader>a")

	h.assert_contains(notified, "Only a file can be pinned", "scratch buffer")
end

function tests.a_pin_whose_file_went_away_says_so()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	edit(root, "b.txt")
	vim.fn.delete(vim.fs.joinpath(root, "a.txt"))
	local notified = h.capture_notifications()

	h.press("<leader>1")

	h.assert_contains(notified, "Pinned a.txt no longer exists", "missing file")
	h.assert_equal(current(root), "b.txt", "stayed put")
end

function tests.a_corrupt_store_is_reported_and_never_overwritten()
	local root = project()
	local store = vim.fs.joinpath(vim.fn.stdpath("data"), "pins.json")
	vim.fn.mkdir(vim.fs.dirname(store), "p")
	vim.fn.writefile({ "not json" }, store)
	local notified = h.capture_notifications()
	edit(root, "a.txt")

	h.press("<leader>a")

	h.assert_contains(notified, "not a JSON object", "report")
	h.assert_equal(vim.fn.readfile(store), { "not json" }, "store")
end

function tests.the_list_saves_reordering_and_removal_on_close()
	local root = project()
	for _, name in ipairs({ "a.txt", "b.txt", "src/c.txt" }) do
		edit(root, name)
		h.press("<leader>a")
	end
	h.press("<leader>A")
	h.assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "a.txt", "b.txt", "src/c.txt" }, "listed pins")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "src/c.txt", "a.txt" })

	h.press("q")

	h.press("<leader>1")
	h.assert_equal(current(root), "src/c.txt", "new first pin")
	local notified = h.capture_notifications()
	h.press("<leader>3")
	h.assert_contains(notified, "No pin 3", "removed pin")
end

function tests.leaving_the_list_saves_it_too()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	h.press("<leader>A")
	local float = vim.api.nvim_get_current_win()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

	vim.cmd.wincmd("p")

	h.assert_equal(vim.api.nvim_win_is_valid(float), false, "list closed")
	local notified = h.capture_notifications()
	h.press("<leader>1")
	h.assert_contains(notified, "No pin 1", "emptied list")
end

function tests.enter_on_a_line_of_the_list_opens_it()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	edit(root, "b.txt")
	h.press("<leader>a")
	h.press("<leader>A")
	vim.api.nvim_win_set_cursor(0, { 2, 0 })

	h.press("<CR>")

	h.assert_equal(current(root), "b.txt", "opened pin")
end

function tests.escape_saves_the_list_like_q()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	h.press("<leader>A")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

	h.press("<Esc>")

	local notified = h.capture_notifications()
	h.press("<leader>1")
	h.assert_contains(notified, "No pin 1", "saved list")
end

function tests.enter_on_a_blank_line_of_the_list_opens_nothing()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	h.press("<leader>A")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "" })

	h.press("<CR>")

	h.assert_equal(current(root), "a.txt", "stayed put")
end

function tests.a_file_outside_the_project_stays_pinned_by_its_full_path()
	local root = project()
	local outside = h.temp_dir() .. "/outside.txt"
	vim.fn.writefile({ "x" }, outside)
	vim.cmd.edit(outside)
	vim.api.nvim_buf_set_name(0, outside)
	h.press("<leader>A")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { outside })
	h.press("q")
	vim.cmd.cd(root)
	edit(root, "a.txt")
	h.press("<leader>A")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { outside })
	h.press("q")

	h.press("<leader>1")

	h.assert_equal(vim.api.nvim_buf_get_name(0), outside, "opened")
end

function tests.a_buffer_that_is_no_file_uses_the_working_folder_s_project()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	vim.cmd.enew()
	vim.bo.buftype = "nofile"

	h.press("<leader>1")

	h.assert_equal(current(root), "a.txt", "opened")
end

function tests.a_file_outside_any_repo_pins_against_the_working_folder()
	local dir = h.temp_dir()
	vim.cmd.cd(dir)
	require("plugins.editor.pins")
	vim.fn.writefile({ "x" }, dir .. "/a.txt")
	vim.cmd.edit(dir .. "/a.txt")
	h.press("<leader>a")
	vim.cmd.enew()

	h.press("<leader>1")

	h.assert_equal(vim.fs.basename(vim.api.nvim_buf_get_name(0)), "a.txt", "opened")
end

function tests.the_list_window_numbers_its_lines()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	h.press("<leader>A")

	h.assert_equal({ vim.wo.number, vim.wo.relativenumber, vim.wo.cursorline }, { true, false, true }, "options")
	h.assert_equal(vim.bo.bufhidden, "wipe", "buffer goes with the window")
end

function tests.an_empty_project_removes_its_key_from_the_store()
	local root = project()
	edit(root, "a.txt")
	h.press("<leader>a")
	h.press("<leader>A")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, {})

	h.press("q")

	local store = vim.fs.joinpath(vim.fn.stdpath("data"), "pins.json")
	h.assert_equal(require("lib.json_file").read(store)[root], nil, "project in the store")
end

return tests
