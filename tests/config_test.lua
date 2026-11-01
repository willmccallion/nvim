--- The config's own behaviour: keymaps with logic, the input float, terminals and autocmds.

local h = require("helpers")

local function load_keymaps()
	package.loaded["oil.lsp.workspace"] = package.loaded["oil.lsp.workspace"]
		or {
			will_rename_files = function()
				return nil, nil
			end,
			did_rename_files = function() end,
		}
	require("config.keymaps")
end

---@param lines? string[]
---@return string path
local function file(lines)
	local path = h.temp_dir() .. "/file.txt"
	vim.fn.writefile(lines or { "text" }, path)
	return path
end

---@param answer string?
local function answer_input(answer)
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.input = function(_, on_confirm)
		on_confirm(answer)
	end
end

local tests = {}

function tests.renaming_a_file_moves_it_and_follows_it()
	load_keymaps()
	local notified = h.capture_notifications()
	local old = file()
	local new = vim.fs.dirname(old) .. "/deep/renamed.txt"
	vim.cmd.edit(old)
	answer_input(new)

	h.press("<leader>cR")

	h.assert_equal(vim.uv.fs_stat(old), nil, "old file")
	h.assert_equal(vim.fn.readfile(new), { "text" }, "new file")
	h.assert_equal(vim.api.nvim_buf_get_name(0), new, "buffer")
	h.assert_equal(vim.fn.bufnr(old), -1, "stale buffer")
	h.assert_contains(notified, "Renamed to", "message")
end

function tests.renaming_keeps_edits_made_for_the_language_server()
	load_keymaps()
	h.capture_notifications()
	local old = file()
	local new = vim.fs.dirname(old) .. "/renamed.txt"
	vim.cmd.edit(old)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "unsaved" })
	answer_input(new)

	h.press("<leader>cR")

	h.assert_equal(vim.fn.readfile(new), { "unsaved" }, "written file")
end

function tests.renaming_never_replaces_a_file_already_there()
	load_keymaps()
	local notified = h.capture_notifications()
	local old = file({ "mine" })
	local taken = vim.fs.dirname(old) .. "/taken.txt"
	vim.fn.writefile({ "theirs" }, taken)
	vim.cmd.edit(old)
	answer_input(taken)

	h.press("<leader>cR")

	h.assert_contains(notified, "already exists", "message")
	h.assert_equal(vim.fn.readfile(taken), { "theirs" }, "existing file")
	h.assert_equal(vim.fn.readfile(old), { "mine" }, "original file")
end

function tests.renaming_to_the_same_name_or_nothing_does_nothing()
	load_keymaps()
	local notified = h.capture_notifications()
	local old = file()
	vim.cmd.edit(old)

	for _, answer in ipairs({ old, "" }) do
		answer_input(answer)
		h.press("<leader>cR")
	end

	h.assert_equal(notified, {}, "messages")
	h.assert_equal(vim.fn.readfile(old), { "text" }, "file")
end

function tests.a_refusing_language_server_warns_but_the_rename_goes_ahead()
	load_keymaps()
	local notified = h.capture_notifications()
	package.loaded["oil.lsp.workspace"].will_rename_files = function()
		return nil, { message = "server said no" }
	end
	local old = file()
	local new = vim.fs.dirname(old) .. "/renamed.txt"
	vim.cmd.edit(old)
	answer_input(new)

	h.press("<leader>cR")

	h.assert_contains(notified, "did not update references: server said no", "warning")
	h.assert_equal(vim.fn.filereadable(new), 1, "renamed anyway")
end

function tests.a_failed_rename_says_so_and_stays_on_the_old_file()
	load_keymaps()
	local notified = h.capture_notifications()
	local old = file()
	local blocked = vim.fs.dirname(old) .. "/blocked"
	vim.fn.writefile({}, blocked)
	vim.cmd.edit(old)
	answer_input(blocked .. "/inside.txt")

	pcall(h.press, "<leader>cR")

	h.assert_equal(vim.fn.readfile(old), { "text" }, "old file")
	h.assert_equal(vim.api.nvim_buf_get_name(0), old, "buffer")
	h.refute_contains(notified, "Renamed to", "false success")
end

function tests.only_a_file_on_disk_can_be_renamed()
	load_keymaps()
	local notified = h.capture_notifications()
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.input = function()
		error("it asked for a name")
	end

	h.press("<leader>cR")

	h.assert_contains(notified, "not a file on disk", "message")
end

function tests.copying_a_location_gives_the_path_from_the_git_root()
	load_keymaps()
	local notified = h.capture_notifications()
	local root = h.temp_dir()
	vim.fn.mkdir(root .. "/.git", "p")
	vim.fn.mkdir(root .. "/src", "p")
	vim.fn.writefile({ "a", "b", "c" }, root .. "/src/a.lua")
	vim.cmd.edit(root .. "/src/a.lua")
	vim.api.nvim_win_set_cursor(0, { 2, 0 })
	vim.g.clipboard = {
		name = "test",
		copy = {
			["+"] = function(lines)
				vim.g.copied = lines[1]
			end,
			["*"] = function() end,
		},
		paste = {
			["+"] = function()
				return {}
			end,
			["*"] = function()
				return {}
			end,
		},
	}

	h.press("<leader>cy")

	h.assert_equal(vim.g.copied, "src/a.lua:2", "copied")
	h.assert_contains(notified, "Copied src/a.lua:2", "message")
end

function tests.copying_a_location_needs_a_file()
	load_keymaps()
	local notified = h.capture_notifications()

	h.press("<leader>cy")

	h.assert_contains(notified, "not a file", "message")
end

function tests.closing_other_buffers_keeps_unsaved_work_and_terminals()
	load_keymaps()
	local notified = h.capture_notifications()
	vim.cmd.edit(file())
	local clean = vim.api.nvim_get_current_buf()
	vim.cmd.edit(vim.fs.dirname(file()) .. "/unsaved.txt")
	local unsaved = vim.api.nvim_get_current_buf()
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "work" })
	vim.bo.bufhidden = "hide"
	vim.cmd("hide terminal true")
	local terminal = vim.api.nvim_get_current_buf()
	vim.bo.bufhidden = "hide"
	vim.cmd.edit(file())

	h.press("<leader>bo")

	h.assert_equal(vim.api.nvim_buf_is_loaded(clean), false, "clean buffer closed")
	h.assert_equal(vim.api.nvim_buf_is_valid(unsaved), true, "unsaved buffer")
	h.assert_equal(vim.api.nvim_buf_is_valid(terminal), true, "terminal")
	h.assert_contains(notified, "Kept (unsaved or terminal): unsaved.txt", "message")
end

function tests.zooming_a_window_and_again_puts_the_layout_back()
	load_keymaps()
	vim.o.columns, vim.o.lines = 100, 40
	vim.cmd("vsplit")
	local before = vim.fn.winrestcmd()

	h.press("<leader>wm")
	h.assert_equal(vim.t.layout_before_zoom, before, "saved layout")
	h.assert_equal(vim.fn.winrestcmd() ~= before, true, "zoomed")

	h.press("<leader>wm")
	h.assert_equal(vim.fn.winrestcmd(), before, "restored layout")
	h.assert_equal(vim.t.layout_before_zoom, nil, "nothing saved")
end

function tests.the_quickfix_key_toggles_its_window()
	load_keymaps()

	h.press("<leader>q")
	h.assert_equal(vim.fn.getqflist({ winid = 0 }).winid ~= 0, true, "opened")
	h.press("<leader>q")
	h.assert_equal(vim.fn.getqflist({ winid = 0 }).winid, 0, "closed")
end

function tests.j_and_k_move_by_screen_line_unless_counted()
	load_keymaps()
	local down = vim.fn.maparg("j", "n", false, true).callback
	local up = vim.fn.maparg("k", "n", false, true).callback

	h.assert_equal({ down(), up() }, { "gj", "gk" }, "without a count")
end

function tests.q_quits_every_window()
	load_keymaps()
	h.assert_equal(vim.api.nvim_get_commands({}).Q.definition, "qall<bang>", "command")
end

function tests.the_input_float_confirms_with_enter_and_gives_the_text()
	require("config.input")
	local answers = {}
	vim.ui.input({ prompt = "Name: ", default = "start" }, function(answer)
		table.insert(answers, answer)
	end)
	h.assert_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "start" }, "default")
	h.assert_equal(vim.b.ui_input, true, "marked for the completion plugin")
	h.assert_contains({ vim.api.nvim_win_get_config(0).title[1][1] }, " Name ", "title")
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { "typed" })

	h.press("<CR>", "i")

	h.assert_equal(answers, { "typed" }, "answers")
	h.assert_equal(#vim.api.nvim_list_wins(), 1, "float closed")
end

function tests.the_input_float_cancels_with_escape_or_ctrl_c_or_leaving_it()
	require("config.input")
	for _, cancel in ipairs({ "<Esc>", "<C-c>", "leave" }) do
		local answers = {}
		local float_opened = vim.api.nvim_get_current_win()
		vim.ui.input({}, function(answer)
			table.insert(answers, answer == nil and "nil" or answer)
		end)
		if cancel == "leave" then
			vim.api.nvim_set_current_win(float_opened)
		else
			h.press(cancel, "i")
		end
		h.assert_equal(answers, { "nil" }, cancel)
		h.assert_equal(#vim.api.nvim_list_wins(), 1, cancel .. " closes it")
	end
end

function tests.the_input_float_answers_exactly_once()
	require("config.input")
	local answers = 0
	vim.ui.input({}, function()
		answers = answers + 1
	end)

	h.press("<CR>", "i")
	vim.cmd.doautocmd("BufLeave")

	h.assert_equal(answers, 1, "answers")
end

function tests.the_input_float_names_itself_input_with_no_prompt()
	require("config.input")
	vim.ui.input({ prompt = "  :  " }, function() end)

	h.assert_contains({ vim.api.nvim_win_get_config(0).title[1][1] }, " Input ", "title")
end

function tests.the_input_float_grows_with_a_long_default_up_to_the_screen()
	require("config.input")
	vim.o.columns = 80
	vim.ui.input({ default = ("x"):rep(40) }, function() end)
	h.assert_equal(vim.api.nvim_win_get_config(0).width, 41, "long default")
	h.press("<Esc>", "i")
	vim.ui.input({ default = ("x"):rep(300) }, function() end)
	h.assert_equal(vim.api.nvim_win_get_config(0).width, 76, "too long for the screen")
end

function tests.only_a_prompt_that_asked_for_completion_maps_tab()
	require("config.input")
	vim.ui.input({}, function() end)
	h.assert_equal(vim.fn.maparg("<Tab>", "i", false, true).buffer, 0, "plain prompt")
	h.press("<Esc>", "i")

	local dir = h.temp_dir()
	vim.fn.writefile({}, dir .. "/complete_me.txt")
	vim.ui.input({ completion = "file", default = dir .. "/compl" }, function() end)
	h.assert_equal(vim.fn.maparg("<Tab>", "i", false, true).buffer, 1, "file prompt")
end

function tests.a_terminal_toggle_hides_and_brings_back_the_same_session()
	load_keymaps()
	require("config.terminal")
	vim.o.shell = "sh"

	h.press("<leader>tt")
	local terminal = vim.api.nvim_get_current_buf()
	h.assert_equal(vim.bo.buftype, "terminal", "opened")
	h.press("<leader>tt")
	h.assert_equal(#vim.fn.win_findbuf(terminal), 0, "hidden")
	h.press("<leader>tt")
	h.assert_equal(vim.api.nvim_get_current_buf(), terminal, "same session")
end

function tests.an_exited_terminal_is_replaced_by_a_new_one()
	require("config.terminal")
	vim.o.shell = "true"

	h.press("<leader>tv")
	local terminal = vim.api.nvim_get_current_buf()
	vim.wait(1000, function()
		return vim.fn.jobwait({ vim.bo[terminal].channel }, 0)[1] ~= -1
	end, 10)
	vim.cmd.hide()
	h.press("<leader>tv")

	h.assert_equal(vim.api.nvim_get_current_buf() ~= terminal, true, "new terminal")
end

function tests.the_last_window_is_not_hidden_by_its_terminal_key()
	require("config.terminal")
	local notified = h.capture_notifications()
	vim.o.shell = "sh"
	h.press("<leader>tt")
	vim.cmd.only()

	h.press("<leader>tt")

	h.assert_contains(notified, "only window", "message")
	h.assert_equal(#vim.api.nvim_list_wins(), 1, "windows")
end

function tests.the_status_line_names_attached_servers_and_marks_a_loading_one()
	local statusline = require("config.statusline")
	h.assert_equal(statusline.lsp_names(), "", "no servers")
	h.assert_contains({ vim.o.statusline }, "lsp_names", "status line")
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.get_clients = function()
		return {
			{ id = 1, name = "ruff", config = {} },
			{
				id = 2,
				name = "pyright",
				config = { capabilities = { experimental = { serverStatusNotification = true } } },
			},
		}
	end

	h.assert_equal(statusline.lsp_names(), "pyright… ruff", "sorted and marked")
end

function tests.a_file_reopens_at_the_last_cursor_position()
	require("config.autocmds")
	local path = file({ "1", "2", "3" })
	vim.cmd.edit(path)
	vim.api.nvim_win_set_cursor(0, { 3, 0 })
	vim.cmd("bwipeout")
	vim.cmd.edit(path)
	vim.api.nvim_buf_set_mark(0, '"', 2, 0, {})

	vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0 })

	h.assert_equal(vim.fn.line("."), 2, "cursor")
end

function tests.a_commit_message_always_starts_at_the_top()
	require("config.autocmds")
	local path = h.temp_dir() .. "/COMMIT_EDITMSG"
	vim.fn.writefile({ "1", "2", "3" }, path)
	vim.cmd.edit(path)
	vim.api.nvim_buf_set_mark(0, '"', 3, 0, {})
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0 })

	h.assert_equal(vim.fn.line("."), 1, "cursor")
end

function tests.a_stale_mark_past_the_end_of_the_file_is_ignored()
	require("config.autocmds")
	vim.cmd.edit(file({ "1", "2", "3" }))
	vim.api.nvim_buf_set_mark(0, '"', 3, 0, {})
	vim.api.nvim_buf_set_lines(0, 1, -1, false, {})
	vim.api.nvim_win_set_cursor(0, { 1, 0 })

	vim.api.nvim_exec_autocmds("BufReadPost", { buffer = 0 })

	h.assert_equal(vim.fn.line("."), 1, "cursor")
end

function tests.a_reload_from_disk_is_announced_but_not_a_declined_one()
	require("config.autocmds")
	local notified = h.capture_notifications()
	local path = file()
	vim.cmd.edit(path)

	vim.api.nvim_exec_autocmds("FileChangedShellPost", { pattern = path })
	h.assert_contains(notified, "changed on disk", "reload")

	vim.bo.modified = true
	vim.api.nvim_exec_autocmds("FileChangedShellPost", { pattern = path })
	h.assert_equal(#notified, 1, "declined reload")
end

function tests.the_clipboard_uses_wayland_only_when_it_can_reach_it()
	vim.env.WAYLAND_DISPLAY = nil
	package.loaded["config.clipboard"] = nil
	require("config.clipboard")
	h.assert_equal(type(vim.g.clipboard.paste["+"]), "function", "over SSH, the terminal")

	vim.env.WAYLAND_DISPLAY = "wayland-1"
	local bin = h.temp_dir()
	for _, tool in ipairs({ "wl-copy", "wl-paste" }) do
		vim.fn.writefile({ "#!/bin/sh" }, bin .. "/" .. tool)
		vim.fn.setfperm(bin .. "/" .. tool, "rwxr-xr-x")
	end
	vim.env.PATH = bin .. ":" .. vim.env.PATH
	package.loaded["config.clipboard"] = nil
	require("config.clipboard")
	h.assert_equal(vim.g.clipboard.paste["+"], { "wl-paste", "--no-newline" }, "at the desktop")
	h.assert_equal(vim.g.clipboard.paste["*"], { "wl-paste", "--no-newline", "--primary" }, "primary selection")
end

---@param results table
local function stub_definitions(results)
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.buf_request_all = function(_, _, _, on_result)
		on_result(results)
	end
end

local function location(path, line)
	return { uri = vim.uri_from_fname(path), range = { start = { line = line, character = 0 } } }
end

function tests.peeking_opens_the_definition_in_a_float_at_its_line()
	local peek = require("plugins.lsp.peek")
	local path = file({ "1", "2", "3", "4" })
	vim.cmd.edit(h.temp_dir() .. "/other.txt")
	stub_definitions({ [1] = { result = { location(path, 2) } } })

	peek.definition()

	local floats = vim.tbl_filter(function(win)
		return vim.api.nvim_win_get_config(win).relative ~= ""
	end, vim.api.nvim_list_wins())
	h.assert_equal(#floats, 1, "floats")
	h.assert_equal(vim.api.nvim_win_get_cursor(floats[1])[1], 3, "line")
end

function tests.a_location_link_uses_its_whole_range_and_shows_unsaved_edits()
	local peek = require("plugins.lsp.peek")
	local path = file({ "1", "2", "3" })
	vim.cmd.edit(path)
	vim.api.nvim_buf_set_lines(0, 0, 1, false, { "unsaved" })
	stub_definitions({
		[1] = {
			result = {
				{ targetUri = vim.uri_from_fname(path), targetRange = { start = { line = 0, character = 0 } } },
			},
		},
	})

	peek.definition()

	local floats = vim.tbl_filter(function(win)
		return vim.api.nvim_win_get_config(win).relative ~= ""
	end, vim.api.nvim_list_wins())
	local buf = vim.api.nvim_win_get_buf(floats[1])
	h.assert_equal(vim.api.nvim_buf_get_lines(buf, 0, 1, false), { "unsaved" }, "first line")
end

function tests.enter_in_the_float_goes_to_that_line_of_the_file()
	local peek = require("plugins.lsp.peek")
	local path = file({ "1", "2", "3", "4" })
	vim.cmd.edit(h.temp_dir() .. "/other.txt")
	stub_definitions({ [1] = { result = location(path, 1) } })
	peek.definition()
	peek.definition()
	h.assert_equal(vim.api.nvim_win_get_config(0).relative ~= "", true, "second press moves into the float")
	vim.api.nvim_win_set_cursor(0, { 3, 0 })

	h.press("<CR>")

	h.assert_equal(vim.api.nvim_buf_get_name(0), path, "file")
	h.assert_equal(vim.fn.line("."), 3, "line")
end

function tests.peeking_in_a_split_reuses_the_same_split()
	local peek = require("plugins.lsp.peek")
	local first, second = file({ "1", "2" }), file({ "a", "b" })
	vim.cmd.edit(h.temp_dir() .. "/other.txt")
	local here = vim.api.nvim_get_current_win()
	stub_definitions({ [1] = { result = location(first, 1) } })
	peek.definition_in_split()
	stub_definitions({ [1] = { result = location(second, 0) } })

	peek.definition_in_split()

	h.assert_equal(#vim.api.nvim_list_wins(), 2, "windows")
	h.assert_equal(vim.api.nvim_get_current_win(), here, "stayed here")
	local split = vim.tbl_filter(function(win)
		return win ~= here
	end, vim.api.nvim_list_wins())[1]
	h.assert_equal(vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(split)), second, "file")
end

function tests.no_definition_says_so()
	local peek = require("plugins.lsp.peek")
	local notified = h.capture_notifications()
	stub_definitions({ [1] = { result = nil }, [2] = { result = {} } })

	peek.definition()

	h.assert_contains(notified, "No definition found", "message")
end

return tests
