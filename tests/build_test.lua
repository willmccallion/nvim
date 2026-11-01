--- The build runner, driven through its keys with real shell commands in a throwaway project.

local h = require("helpers")

local TIMEOUT_MS = 5000

---@return {msg: string, annote: string?, level: any}[]
local function stub_status_popup()
	local statuses = {}
	package.loaded["fidget"] = {
		notification = { set_config = function() end },
		notify = function(msg, level, opts)
			table.insert(statuses, { msg = msg, annote = opts.annote, level = level })
		end,
	}
	return statuses
end

---@param statuses table[]
---@return string
local function latest(statuses)
	local last = statuses[#statuses]
	return last and ((last.annote or "") .. ": " .. last.msg) or ""
end

---@param statuses table[]
---@param annote string
local function wait_for_status(statuses, annote)
	local found = vim.wait(TIMEOUT_MS, function()
		return #statuses > 0 and statuses[#statuses].annote == annote
	end, 10)
	if not found then
		error(("timed out waiting for %s; last status %s"):format(annote, latest(statuses)), 2)
	end
end

---@param makefile string[]
---@return string root
---@return table[] statuses
local function make_project(makefile)
	local statuses = stub_status_popup()
	vim.o.shell = "sh"
	vim.o.shellcmdflag = "-c"
	local root = h.temp_dir()
	vim.fn.mkdir(root .. "/.git", "p")
	vim.fn.mkdir(root .. "/src", "p")
	vim.fn.writefile(makefile, root .. "/Makefile")
	vim.fn.writefile({ "int main;", "int b;", "int c;" }, root .. "/src/a.c")
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/src/a.c")
	require("plugins.coding.build")
	return root, statuses
end

---@return string[]
local function output_lines()
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf) == "build://output" then
			return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
		end
	end
	return {}
end

---@param choose fun(items: table[], format: fun(item: table): string): table?
---@return table list of prompts seen
local function stub_select(choose)
	local seen = {}
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.select = function(items, opts, on_choice)
		table.insert(seen, { prompt = opts.prompt, shown = vim.tbl_map(opts.format_item, items) })
		on_choice(choose(items, opts.format_item))
	end
	return seen
end

---@param answer string?
---@return table list of prompts seen
local function stub_input(answer)
	local seen = {}
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.input = function(opts, on_confirm)
		table.insert(seen, { prompt = opts.prompt, default = opts.default })
		on_confirm(answer)
	end
	return seen
end

local function pick_command(cmd)
	return function(items)
		for _, item in ipairs(items) do
			if item.cmd == cmd then
				return item
			end
		end
		error("no such command offered: " .. tostring(cmd))
	end
end

local function pick_custom(items)
	return items[#items]
end

local ok_makefile = { "all:", "\t@echo hello from make", "clean:", "\t@echo cleaned" }

local tests = {}

function tests.building_runs_the_default_command_and_reports_it_passed()
	local _, statuses = make_project(ok_makefile)

	h.press("<leader>mb")
	wait_for_status(statuses, "Passed")

	h.assert_contains(output_lines(), "hello from make", "output")
	h.assert_equal(statuses[1].annote, "Building", "first status")
	h.assert_contains({ latest(statuses) }, "Passed: make", "final status")
end

function tests.compiler_errors_land_in_quickfix_against_the_project_root()
	local root, statuses = make_project({ "all:", "\t@echo 'src/a.c:2:3: error: bad thing'", "\t@false" })

	h.press("<leader>mb")
	wait_for_status(statuses, "Failed")

	local entries = vim.fn.getqflist()
	h.assert_equal(#entries, 1, "quickfix entries")
	h.assert_equal(vim.api.nvim_buf_get_name(entries[1].bufnr), root .. "/src/a.c", "file")
	h.assert_equal({ entries[1].lnum, entries[1].col }, { 2, 3 }, "position")
	h.assert_contains({ entries[1].text }, "bad thing", "message")
	h.assert_contains({ vim.fn.getqflist({ title = 1 }).title }, "Build: make", "title")
end

function tests.a_failed_build_opens_quickfix_but_keeps_the_cursor_in_the_file()
	local root, statuses = make_project({ "all:", "\t@echo 'src/a.c:1:1: error: nope'", "\t@false" })
	local file_win = vim.api.nvim_get_current_win()

	h.press("<leader>mb")
	wait_for_status(statuses, "Failed")

	h.assert_equal(vim.api.nvim_get_current_win(), file_win, "focus")
	h.assert_equal(vim.fn.getqflist({ winid = 1 }).winid ~= 0, true, "quickfix window")
	h.assert_equal(vim.api.nvim_buf_get_name(0), root .. "/src/a.c", "file")
end

function tests.a_failure_with_no_errors_points_at_the_output_and_opens_nothing()
	local _, statuses = make_project({ "all:", "\t@echo plain words", "\t@exit 3" })

	h.press("<leader>mb")
	wait_for_status(statuses, "Failed")

	h.assert_contains({ latest(statuses) }, "<leader>mo shows the output", "hint")
	h.assert_contains({ latest(statuses) }, "exit 2", "make's exit code")
	h.assert_equal(vim.fn.getqflist({ winid = 1 }).winid, 0, "quickfix window")
end

function tests.a_failing_recipe_line_from_make_is_not_an_error_of_its_own()
	local _, statuses = make_project({ "all:", "\t@false" })

	h.press("<leader>mb")
	wait_for_status(statuses, "Failed")

	local valid = vim.tbl_filter(function(item)
		return item.valid == 1
	end, vim.fn.getqflist())
	h.assert_equal(#valid, 0, "valid entries")
end

function tests.warnings_in_a_passing_build_are_counted()
	local _, statuses = make_project({ "all:", "\t@echo 'src/a.c:1:1: warning: careful'" })

	h.press("<leader>mb")
	wait_for_status(statuses, "Passed")

	h.assert_contains({ latest(statuses) }, "1 quickfix entries", "count")
	h.assert_equal(vim.fn.getqflist({ winid = 1 }).winid, 0, "a passing build opens nothing")
end

function tests.colour_codes_do_not_hide_an_error_from_quickfix()
	local _, statuses = make_project({ "all:", "\t@printf '\\033[1msrc/a.c:1:1: error: coloured\\033[0m\\n'", "\t@false" })

	h.press("<leader>mb")
	wait_for_status(statuses, "Failed")

	h.assert_equal(vim.fn.getqflist()[1].lnum, 1, "line")
	h.assert_contains(output_lines(), "src/a.c:1:1: error: coloured", "plain output")
end

function tests.a_second_build_is_refused_while_one_runs()
	local _, statuses = make_project({ "all:", "\t@sleep 1" })

	h.press("<leader>mb")
	h.press("<leader>mb")

	local refused = vim.tbl_filter(function(status)
		return status.msg:find("Already running", 1, true)
	end, statuses)
	h.assert_equal(#refused, 1, "refusals")
	wait_for_status(statuses, "Passed")
end

function tests.stopping_ends_a_running_build_and_lets_the_next_one_start()
	local _, statuses = make_project({ "all:", "\t@sleep 30" })

	h.press("<leader>mb")
	vim.wait(100)
	h.press("<leader>mk")
	wait_for_status(statuses, "Stopped")

	h.press("<leader>mb")
	h.assert_equal(statuses[#statuses].annote, "Building", "next build started")
	h.press("<leader>mk")
	wait_for_status(statuses, "Stopped")
end

function tests.stopping_with_nothing_running_says_so()
	local _, statuses = make_project(ok_makefile)

	h.press("<leader>mk")

	h.assert_contains({ statuses[#statuses].msg }, "No build is running", "message")
end

function tests.picking_a_command_runs_it_and_makes_it_the_default()
	local root, statuses = make_project(ok_makefile)
	stub_select(pick_command("make clean"))

	h.press("<leader>mp")
	wait_for_status(statuses, "Passed")
	h.assert_contains(output_lines(), "cleaned", "picked command")
	h.assert_equal(require("plugins.coding.build.store").load(root).selected, "make clean", "saved")

	statuses[#statuses] = nil
	h.press("<leader>mb")
	wait_for_status(statuses, "Passed")
	h.assert_contains(output_lines(), "cleaned", "default from then on")
end

function tests.the_picker_marks_the_current_command_and_saved_ones()
	local root = make_project(ok_makefile)
	require("plugins.coding.build.store").save(root, { selected = "make", custom = { "make clean", "typed" }, run_custom = {} })
	local seen = stub_select(function() end)

	h.press("<leader>mp")

	h.assert_equal(seen[1].shown, { "* make", "  make clean", "  typed  (saved)", "Custom..." }, "items")
	h.assert_contains({ seen[1].prompt }, "Build command (make, ", "prompt")
end

function tests.a_custom_command_is_trimmed_remembered_and_run()
	local root, statuses = make_project(ok_makefile)
	stub_select(pick_custom)
	stub_input("  echo typed  ")

	h.press("<leader>mp")
	wait_for_status(statuses, "Passed")

	h.assert_contains(output_lines(), "typed", "output")
	local state = require("plugins.coding.build.store").load(root)
	h.assert_equal({ state.selected, state.custom }, { "echo typed", { "echo typed" } }, "state")
end

function tests.a_blank_or_cancelled_custom_command_does_nothing()
	local root, statuses = make_project(ok_makefile)
	stub_select(pick_custom)
	for _, answer in ipairs({ "   ", false }) do
		stub_input(answer or nil)
		h.press("<leader>mp")
	end

	h.assert_equal(#statuses, 0, "statuses")
	h.assert_equal(require("plugins.coding.build.store").load(root).custom, {}, "custom commands")
end

function tests.cancelling_the_picker_runs_nothing()
	local _, statuses = make_project(ok_makefile)
	stub_select(function() end)

	h.press("<leader>mp")

	h.assert_equal(#statuses, 0, "statuses")
end

function tests.a_project_with_no_build_system_asks_what_to_run()
	local statuses = stub_status_popup()
	require("plugins.coding.build")
	local root = h.temp_dir()
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/notes.txt")
	local seen = stub_select(function() end)

	h.press("<leader>mb")

	h.assert_contains({ seen[1].prompt }, "no build system detected", "prompt")
	h.assert_equal(#statuses, 0, "statuses")
end

function tests.a_custom_build_uses_the_project_s_compiler_for_quickfix()
	local root, statuses = make_project(ok_makefile)
	require("plugins.coding.build.store").save(root, { selected = "./check.sh", custom = {}, run_custom = {} })
	vim.fn.writefile({ "#!/bin/sh", "echo 'src/a.c:3:1: error: custom'", "exit 1" }, root .. "/check.sh")
	vim.fn.setfperm(root .. "/check.sh", "rwxr-xr-x")

	h.press("<leader>mb")
	wait_for_status(statuses, "Failed")

	h.assert_equal(vim.fn.getqflist()[1].lnum, 3, "line")
end

function tests.the_first_run_asks_for_a_command_and_later_runs_reuse_it()
	local root, statuses = make_project(ok_makefile)
	local asked = stub_input("echo ran it")

	h.press("<leader>mr")
	wait_for_status(statuses, "Passed")
	h.assert_contains(output_lines(), "ran it", "first run")
	h.assert_equal(#asked, 1, "prompts")
	h.assert_equal(asked[1].prompt, "Run command: ", "prompt")

	statuses[#statuses] = nil
	h.press("<leader>mr")
	wait_for_status(statuses, "Passed")
	h.assert_equal(#asked, 1, "prompts on the second run")
	h.assert_equal(require("plugins.coding.build.store").load(root).run_custom, { "echo ran it" }, "history")
end

function tests.a_program_s_output_never_reaches_quickfix()
	local _, statuses = make_project(ok_makefile)
	vim.fn.setqflist({}, " ", { title = "before" })
	stub_input("echo 'src/a.c:1:1: error: printed by the program'; exit 1")

	h.press("<leader>mr")
	wait_for_status(statuses, "Failed")

	h.assert_equal(#vim.fn.getqflist(), 0, "quickfix entries")
	h.assert_equal(vim.fn.getqflist({ title = 1 }).title, "before", "quickfix list untouched")
end

function tests.a_blank_run_command_runs_nothing()
	local root, statuses = make_project(ok_makefile)
	stub_input("  ")

	h.press("<leader>mr")

	h.assert_equal(#statuses, 0, "statuses")
	h.assert_equal(require("plugins.coding.build.store").load(root).run, nil, "saved run")
end

function tests.the_run_picker_lists_saved_commands_and_can_take_a_new_one()
	local root, statuses = make_project(ok_makefile)
	require("plugins.coding.build.store").save(root, { custom = {}, run = "echo one", run_custom = { "echo one", "echo two" } })
	local seen = stub_select(pick_command("echo two"))

	h.press("<leader>mP")
	wait_for_status(statuses, "Passed")

	h.assert_equal(seen[1].shown, { "* echo one", "  echo two", "Custom..." }, "items")
	h.assert_contains(output_lines(), "two", "picked command")
	h.assert_equal(require("plugins.coding.build.store").load(root).run, "echo two", "new default")
end

function tests.the_run_picker_asks_outright_when_nothing_is_saved_or_custom_is_picked()
	local root, statuses = make_project(ok_makefile)
	local asked = stub_input("echo first")
	h.press("<leader>mP")
	wait_for_status(statuses, "Passed")
	h.assert_equal(#asked, 1, "no saved commands")

	stub_select(pick_custom)
	statuses[#statuses] = nil
	stub_input("echo second")
	h.press("<leader>mP")
	wait_for_status(statuses, "Passed")
	h.assert_equal(require("plugins.coding.build.store").load(root).run, "echo second", "typed command")

	stub_select(function() end)
	h.press("<leader>mP")
	h.assert_equal(require("plugins.coding.build.store").load(root).run, "echo second", "cancelled picker")
end

function tests.the_output_window_toggles_and_opens_at_the_end()
	local _, statuses = make_project(ok_makefile)
	h.press("<leader>mo")
	h.assert_contains({ statuses[#statuses].msg }, "No build output yet", "before any build")

	h.press("<leader>mb")
	wait_for_status(statuses, "Passed")
	local windows = #vim.api.nvim_list_wins()
	h.press("<leader>mo")
	h.assert_equal(vim.api.nvim_buf_get_name(0), "build://output", "output shown")
	h.assert_equal(#vim.api.nvim_list_wins(), windows + 1, "a window opened")
	h.assert_equal(vim.fn.line("."), vim.fn.line("$"), "cursor at the end")

	h.press("<leader>mo")
	h.assert_equal(#vim.api.nvim_list_wins(), windows, "the window closed")
end

function tests.a_window_at_the_end_follows_the_output_but_one_scrolled_back_stays()
	local _, statuses = make_project({ "all:", "\t@echo one; echo two; sleep 0.3; echo three; echo four" })
	h.press("<leader>mb")
	vim.wait(TIMEOUT_MS, function()
		return #output_lines() >= 2
	end, 10)
	h.press("<leader>mo")
	local follower = vim.api.nvim_get_current_win()
	vim.cmd("split")
	local scrolled = vim.api.nvim_get_current_win()
	vim.api.nvim_win_set_cursor(scrolled, { 1, 0 })

	wait_for_status(statuses, "Passed")

	h.assert_equal(vim.api.nvim_win_get_cursor(scrolled)[1], 1, "scrolled back")
	h.assert_equal(vim.api.nvim_win_get_cursor(follower)[1], vim.api.nvim_buf_line_count(0), "following")
end

function tests.a_debug_build_reports_back_with_its_project()
	local root = h.temp_dir()
	vim.fn.writefile({ "[package]" }, root .. "/Cargo.toml")
	vim.fn.mkdir(root .. "/.git", "p")
	local statuses = stub_status_popup()
	vim.o.shell, vim.o.shellcmdflag = "sh", "-c"
	local bin = h.temp_dir()
	vim.fn.writefile({ "#!/bin/sh", "exit 1" }, bin .. "/cargo")
	vim.fn.setfperm(bin .. "/cargo", "rwxr-xr-x")
	vim.env.PATH = bin .. ":" .. vim.env.PATH
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/main.rs")
	local build = require("plugins.coding.build")
	h.assert_equal(build.has_debug_build(), true, "cargo has one")

	local outcome
	h.assert_equal(build.debug_build(function(succeeded, project)
		outcome = { succeeded, project.root }
	end), true, "started")
	wait_for_status(statuses, "Failed")

	h.assert_equal(outcome, { false, root }, "outcome")
end

function tests.a_makefile_project_has_no_debug_build()
	make_project(ok_makefile)
	local build = require("plugins.coding.build")

	h.assert_equal(build.has_debug_build(), false, "has one")
	h.assert_equal(build.debug_build(function() end), false, "started")
end

function tests.a_refused_debug_build_says_it_failed()
	local root = h.temp_dir()
	vim.fn.writefile({ "[package]" }, root .. "/Cargo.toml")
	stub_status_popup()
	vim.o.shell, vim.o.shellcmdflag = "sh", "-c"
	local bin = h.temp_dir()
	vim.fn.writefile({ "#!/bin/sh", "sleep 1" }, bin .. "/cargo")
	vim.fn.setfperm(bin .. "/cargo", "rwxr-xr-x")
	vim.env.PATH = bin .. ":" .. vim.env.PATH
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/main.rs")
	local build = require("plugins.coding.build")
	build.debug_build(function() end)
	local second

	build.debug_build(function(succeeded)
		second = succeeded
	end)

	h.assert_equal(second, false, "second build")
end

function tests.the_debug_target_is_remembered_per_project_and_keeps_what_is_not_changed()
	local root = make_project(ok_makefile)
	local build = require("plugins.coding.build")

	build.remember_debug_target(root, { program = "/bin/app", args = "-v" })
	build.remember_debug_target(root, { args = "-q" })

	h.assert_equal(build.debug_target(), { root = root, program = "/bin/app", args = "-q" }, "target")
end

---@param path string
---@param lines string[]
---@param line integer
---@param filetype string
local function open_test_file(path, lines, line, filetype)
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile(lines, path)
	vim.cmd.edit(path)
	vim.bo.filetype = filetype
	vim.treesitter.start(0, filetype)
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	vim.cmd.normal({ "^", bang = true })
end

local RUST_FILE = {
	"mod outer {",
	"    mod tests {",
	"        fn helper() {}",
	"",
	"        /// Doc comment",
	"        #[test]",
	"        fn adds() {",
	"            fn nested() {}",
	"            assert!(true);",
	"        }",
	"",
	"        #[tokio::test]",
	"        async fn waits() {}",
	"    }",
	"}",
}

--- A Cargo package with a fake cargo that says how many tests it ran.
---@param ran integer
---@return string root
---@return table[] statuses
local function cargo_project(ran)
	local statuses = stub_status_popup()
	vim.o.shell, vim.o.shellcmdflag = "sh", "-c"
	local root = h.temp_dir()
	vim.fn.mkdir(root .. "/.git", "p")
	vim.fn.writefile({ "[package]" }, root .. "/Cargo.toml")
	local bin = h.temp_dir()
	vim.fn.writefile({ "#!/bin/sh", 'echo "$@" >"$CARGO_ARGS"', ("echo 'running %d tests'"):format(ran) }, bin .. "/cargo")
	vim.fn.setfperm(bin .. "/cargo", "rwxr-xr-x")
	vim.env.PATH = bin .. ":" .. vim.env.PATH
	vim.env.CARGO_ARGS = h.temp_dir() .. "/args"
	vim.cmd.cd(root)
	require("plugins.coding.build")
	return root, statuses
end

function tests.the_rust_test_under_the_cursor_runs_by_its_full_path()
	local root, statuses = cargo_project(1)
	open_test_file(root .. "/src/parser.rs", RUST_FILE, 9, "rust")

	h.press("<leader>mt")
	wait_for_status(statuses, "Passed")

	h.assert_equal(vim.fn.readfile(vim.env.CARGO_ARGS), { "test -- --exact parser::outer::tests::adds" }, "arguments")
	h.assert_contains({ latest(statuses) }, "parser::outer::tests::adds", "status names the test")
end

function tests.a_wrapped_test_attribute_counts_as_a_test()
	local root, statuses = cargo_project(1)
	open_test_file(root .. "/src/parser.rs", RUST_FILE, 13, "rust")

	h.press("<leader>mt")
	wait_for_status(statuses, "Passed")

	h.assert_contains(vim.fn.readfile(vim.env.CARGO_ARGS), "parser::outer::tests::waits", "arguments")
end

function tests.a_plain_function_in_a_test_module_runs_the_whole_module()
	local root, statuses = cargo_project(1)
	open_test_file(root .. "/src/parser.rs", RUST_FILE, 3, "rust")

	h.press("<leader>mt")
	wait_for_status(statuses, "Passed")

	h.assert_equal(vim.fn.readfile(vim.env.CARGO_ARGS), { "test -- parser::outer::tests::" }, "arguments")
end

function tests.a_test_filter_that_matches_nothing_counts_as_a_failure()
	local root, statuses = cargo_project(0)
	open_test_file(root .. "/src/parser.rs", RUST_FILE, 9, "rust")

	h.press("<leader>mt")
	wait_for_status(statuses, "Failed")

	h.assert_contains({ latest(statuses) }, "No test matched", "status")
end

function tests.a_cursor_outside_any_test_says_so()
	local root, statuses = cargo_project(1)
	open_test_file(root .. "/src/main.rs", { "fn main() {}" }, 1, "rust")

	h.press("<leader>mt")

	h.assert_contains({ statuses[#statuses].msg }, "No #[test] function", "message")
end

function tests.a_rust_file_cargo_builds_no_tests_from_says_so()
	local root, statuses = cargo_project(1)
	open_test_file(root .. "/build.rs", { "fn main() {}" }, 1, "rust")

	h.press("<leader>mt")

	h.assert_contains({ statuses[#statuses].msg }, "Cargo builds no tests from this file", "message")
end

function tests.a_workspace_member_runs_through_its_own_manifest()
	local root, statuses = cargo_project(1)
	vim.fn.mkdir(root .. "/crates/a", "p")
	vim.fn.writefile({ "[package]" }, root .. "/crates/a/Cargo.toml")
	open_test_file(root .. "/crates/a/src/lib.rs", { "#[test]", "fn t() {", "    x();", "}" }, 3, "rust")

	h.press("<leader>mt")
	wait_for_status(statuses, "Passed")

	h.assert_contains(vim.fn.readfile(vim.env.CARGO_ARGS), "--manifest-path crates/a/Cargo.toml", "arguments")
end

function tests.a_rust_file_with_no_cargo_toml_says_so()
	local statuses = stub_status_popup()
	require("plugins.coding.build")
	local root = h.temp_dir()
	vim.cmd.cd(root)
	open_test_file(root .. "/a.rs", { "fn main() {}" }, 1, "rust")

	h.press("<leader>mt")

	h.assert_contains({ statuses[#statuses].msg }, "No Cargo.toml above this file", "message")
end

local PYTHON_FILE = {
	"def helper():",
	"    pass",
	"",
	"class TestThing:",
	"    def test_one(self):",
	"        pass",
	"",
	"    def other(self):",
	"        pass",
}

--- A pytest project with a fake python3 that records its arguments.
---@return string root
---@return table[] statuses
local function python_project()
	local statuses = stub_status_popup()
	vim.o.shell, vim.o.shellcmdflag = "sh", "-c"
	local root = h.temp_dir()
	vim.fn.writefile({ "[tool.pytest]" }, root .. "/pyproject.toml")
	local bin = h.temp_dir()
	vim.fn.writefile({ "#!/bin/sh", 'echo "$@" >"$PYTEST_ARGS"' }, bin .. "/python3")
	vim.fn.setfperm(bin .. "/python3", "rwxr-xr-x")
	vim.env.PATH = bin .. ":" .. vim.env.PATH
	vim.env.PYTEST_ARGS = h.temp_dir() .. "/args"
	vim.cmd.cd(root)
	require("plugins.coding.build")
	return root, statuses
end

function tests.the_pytest_test_under_the_cursor_runs_by_its_node_id()
	local root, statuses = python_project()
	open_test_file(root .. "/tests/test_a.py", PYTHON_FILE, 6, "python")

	h.press("<leader>mt")
	wait_for_status(statuses, "Passed")

	h.assert_equal(vim.fn.readfile(vim.env.PYTEST_ARGS), { "-m pytest tests/test_a.py::TestThing::test_one" }, "arguments")
end

function tests.a_helper_in_a_test_class_runs_the_class()
	local root, statuses = python_project()
	open_test_file(root .. "/tests/test_a.py", PYTHON_FILE, 9, "python")

	h.press("<leader>mt")
	wait_for_status(statuses, "Passed")

	h.assert_equal(vim.fn.readfile(vim.env.PYTEST_ARGS), { "-m pytest tests/test_a.py::TestThing" }, "arguments")
end

function tests.a_python_function_that_is_no_test_says_so()
	local root, statuses = python_project()
	open_test_file(root .. "/tests/test_a.py", PYTHON_FILE, 2, "python")

	h.press("<leader>mt")

	h.assert_contains({ statuses[#statuses].msg }, "No test function or Test class", "message")
end

function tests.running_a_test_needs_a_rust_or_python_file()
	local statuses = stub_status_popup()
	require("plugins.coding.build")

	h.press("<leader>mt")
	h.assert_contains({ statuses[#statuses].msg }, "Not a file", "empty buffer")

	vim.cmd.edit(h.temp_dir() .. "/a.lua")
	vim.bo.filetype = "lua"
	h.press("<leader>mt")
	h.assert_contains({ statuses[#statuses].msg }, "not lua", "other language")
end

return tests
