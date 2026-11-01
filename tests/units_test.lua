--- Pure logic, with no windows, repos or plugins beyond what each module needs.

local h = require("helpers")

local function list()
	return require("plugins.editor.pins.list")
end

local function detect()
	return require("plugins.coding.build.detect")
end

local function build_tests()
	return require("plugins.coding.build.tests")
end

local function store()
	return require("plugins.coding.build.store")
end

local function glob()
	return require("plugins.editor.telescope.glob")
end

local function json_file()
	return require("lib.json_file")
end

local function listing(dir, ...)
	local files = {}
	for _, name in ipairs({ ... }) do
		files[name] = true
	end
	return { dir = dir, files = files }
end

local tests = {}

function tests.adding_a_pin_appends_without_changing_the_list_given()
	local pins = { "a" }
	local added, number = list().add(pins, "b")
	h.assert_equal({ added, number }, { { "a", "b" }, 2 }, "added")
	h.assert_equal(pins, { "a" }, "original list")
end

function tests.adding_a_pin_already_there_keeps_its_number()
	h.assert_equal({ list().add({ "a", "b" }, "a") }, { { "a", "b" }, 1 }, "added")
end

function tests.pin_lines_drop_blanks_and_repeats_and_shorten_full_paths()
	local pins = list().from_lines({ " a ", "", "a", "/root/b/c", "/elsewhere/d", "./e/../f" }, "/root")
	h.assert_equal(pins, { "a", "b/c", "/elsewhere/d", "f" }, "pins")
end

function tests.cargo_beats_cmake_beats_make_in_one_folder()
	local project = detect().project({ listing("/p", "Makefile", "CMakeLists.txt", "Cargo.toml") }, "/fallback")
	h.assert_equal(project, { root = "/p", kind = "cargo" }, "cargo first")
	project = detect().project({ listing("/p", "Makefile", "CMakeLists.txt") }, "/fallback")
	h.assert_equal(project.kind, "cmake", "cmake next")
end

function tests.a_workspace_and_a_cmake_tree_use_their_outermost_folder()
	local project =
		detect().project({ listing("/w/a/b", "Cargo.toml"), listing("/w/a"), listing("/w", "Cargo.toml") }, "/f")
	h.assert_equal(project, { root = "/w", kind = "cargo" }, "workspace")
	project = detect().project({ listing("/c/x", "CMakeLists.txt"), listing("/c", "CMakeLists.txt") }, "/f")
	h.assert_equal(project.root, "/c", "cmake tree")
end

function tests.a_makefile_uses_the_nearest_folder()
	local project = detect().project({ listing("/m/sub", "makefile"), listing("/m", "Makefile") }, "/f")
	h.assert_equal(project, { root = "/m/sub", kind = "make" }, "nearest")
end

function tests.the_nearest_marker_decides_the_build_system()
	local project = detect().project({ listing("/x/sub", "GNUmakefile"), listing("/x", "Cargo.toml") }, "/f")
	h.assert_equal(project.kind, "make", "nearest kind")
end

function tests.no_marker_falls_back_with_no_commands()
	local project = detect().project({ listing("/a"), listing("/") }, "/fallback")
	h.assert_equal(project, { root = "/fallback" }, "fallback")
	h.assert_equal(detect().commands(project), {}, "commands")
end

function tests.commands_are_copies_with_the_default_first()
	local commands = detect().commands({ kind = "make" })
	h.assert_equal(commands[1].cmd, "make", "default")
	commands[1].cmd = "changed"
	h.assert_equal(detect().commands({ kind = "make" })[1].cmd, "make", "shared table untouched")
end

function tests.the_debug_build_prefers_p_and_has_nothing_for_make()
	h.assert_equal(detect().debug_build_command({ kind = "make" }, true), nil, "make")
	h.assert_equal(detect().debug_build_command({ kind = "cargo" }, false).cmd, "cargo build", "cargo alone")
	h.assert_equal(detect().debug_build_command({ kind = "cargo" }, true).cmd, "fish -c 'p build -d'", "cargo with p")
	h.assert_equal(detect().debug_build_command({ kind = "cmake" }, true).compiler, "gcc", "cmake with p")
	h.assert_contains({ detect().debug_build_command({ kind = "cmake" }, false).cmd }, "-S . -B build", "cmake alone")
end

function tests.rust_files_map_to_cargo_targets_and_module_paths()
	local cases = {
		["src/lib.rs"] = { flags = {}, modules = {} },
		["src/main.rs"] = { flags = {}, modules = {} },
		["src/parser/lexer.rs"] = { flags = {}, modules = { "parser", "lexer" } },
		["src/parser/mod.rs"] = { flags = {}, modules = { "parser" } },
		["src/bin/tool.rs"] = { flags = { "--bin", "tool" }, modules = {} },
		["src/bin/tool/main.rs"] = { flags = { "--bin", "tool" }, modules = {} },
		["src/bin/tool/util.rs"] = { flags = { "--bin", "tool" }, modules = { "util" } },
		["tests/api.rs"] = { flags = { "--test", "api" }, modules = {} },
		["tests/api/helpers.rs"] = { flags = { "--test", "api" }, modules = { "helpers" } },
	}
	for file, expected in pairs(cases) do
		h.assert_equal(build_tests().rust_target(file), expected, file)
	end
end

function tests.a_rust_file_outside_any_target_has_none()
	h.assert_equal(build_tests().rust_target("build.rs"), nil, "build script")
	h.assert_equal(build_tests().rust_target("benches/a.rs"), nil, "bench")
	h.assert_equal(build_tests().rust_target("src"), nil, "folder")
end

function tests.a_named_rust_test_filters_exactly()
	local test =
		{ target = { flags = { "--bin", "tool" }, modules = { "util" } }, modules = { "tests" }, name = "works" }
	h.assert_equal({ build_tests().rust_filter(test) }, { "util::tests::works", true }, "filter")
	local command = build_tests().rust_command(test)
	h.assert_equal(command.cmd, "cargo test --bin tool -- --exact util::tests::works", "command")
	h.assert_equal({ command.compiler, command.label }, { "cargo", "util::tests::works" }, "label")
end

function tests.a_rust_module_filters_by_prefix()
	local test = { target = { flags = {}, modules = { "util" } }, modules = {} }
	h.assert_equal({ build_tests().rust_filter(test) }, { "util::", false }, "filter")
	local command = build_tests().rust_command(test)
	h.assert_equal(command.cmd, "cargo test -- util::", "command")
	h.assert_equal(command.label, "util::*", "label")
end

function tests.a_workspace_member_names_its_manifest()
	local test = { manifest = "crates/a b/Cargo.toml", target = { flags = {}, modules = {} }, modules = {}, name = "t" }
	h.assert_equal(
		build_tests().rust_command(test).cmd,
		"cargo test --manifest-path 'crates/a b/Cargo.toml' -- --exact t",
		"command"
	)
end

function tests.a_pytest_node_joins_its_file_classes_and_name()
	local test = { file = "tests/test_a.py", classes = { "TestX", "TestY" }, name = "test_z" }
	h.assert_equal(build_tests().pytest_node_id(test), "tests/test_a.py::TestX::TestY::test_z", "node id")
	h.assert_equal(build_tests().pytest_node_id({ file = "a.py", classes = { "TestX" } }), "a.py::TestX", "class only")
	local command = build_tests().pytest_command(test)
	h.assert_equal(command.cmd, "python3 -m pytest 'tests/test_a.py::TestX::TestY::test_z'", "command")
	h.assert_equal(command.compiler, "pytest", "compiler")
end

function tests.cargo_test_counts_add_up_across_binaries()
	local output = { "running 2 tests", "test a ... ok", "running 1 test", "running 0 tests", "not running 9 tests" }
	h.assert_equal(build_tests().cargo_tests_run(output), 3, "count")
end

function tests.the_build_store_keeps_each_project_with_defaults()
	store().save("/a", { selected = "make", custom = { "x" }, run_custom = {} })
	h.assert_equal(store().load("/a").selected, "make", "saved")
	h.assert_equal(store().load("/a").custom, { "x" }, "custom")
	h.assert_equal(store().load("/b"), { custom = {}, run_custom = {} }, "unknown project")
end

function tests.the_build_store_never_overwrites_a_corrupt_file()
	local path = vim.fs.joinpath(vim.fn.stdpath("data"), "build-commands.json")
	vim.fn.mkdir(vim.fs.dirname(path), "p")
	vim.fn.writefile({ "broken" }, path)
	h.capture_notifications()

	store().save("/a", { custom = {}, run_custom = {} })

	h.assert_equal(vim.fn.readfile(path), { "broken" }, "file")
	h.assert_equal(store().load("/a"), { custom = {}, run_custom = {} }, "defaults")
end

function tests.remembered_commands_move_to_the_front_and_cap_at_ten()
	h.assert_equal(store().remember({ "a", "b" }, "b"), { "b", "a" }, "repeat")
	local long = {}
	for index = 1, 12 do
		long[index] = "cmd" .. index
	end
	local kept = store().remember(long, "new")
	h.assert_equal(#kept, 10, "cap")
	h.assert_equal({ kept[1], kept[2], kept[10] }, { "new", "cmd1", "cmd9" }, "order")
end

function tests.json_file_reads_a_missing_or_empty_file_as_an_empty_object()
	local dir = h.temp_dir()
	h.assert_equal(json_file().read(dir .. "/missing.json"), {}, "missing")
	vim.fn.writefile({}, dir .. "/empty.json")
	h.assert_equal(json_file().read(dir .. "/empty.json"), {}, "empty")
end

function tests.json_file_refuses_anything_but_an_object()
	local dir = h.temp_dir()
	local notified = h.capture_notifications()
	vim.fn.writefile({ "12" }, dir .. "/number.json")
	h.assert_equal(json_file().read(dir .. "/number.json"), nil, "number")
	h.assert_contains(notified, "is not a JSON object", "report")
end

function tests.json_file_replaces_the_file_whole_and_leaves_no_temporary()
	local path = h.temp_dir() .. "/state.json"
	json_file().write(path, { a = 1 })
	json_file().write(path, { b = 2 })
	h.assert_equal(json_file().read(path), { b = 2 }, "contents")
	h.assert_equal(vim.uv.fs_stat(path .. ".tmp"), nil, "temporary file")
end

function tests.json_file_reports_a_folder_it_cannot_write_to()
	local notified = h.capture_notifications()
	json_file().write(h.temp_dir() .. "/no/such/folder/state.json", {})
	h.assert_contains(notified, "Could not write", "report")
end

function tests.a_glob_filter_starts_after_the_first_double_space()
	h.assert_equal({ glob().split("config  *.lua  !x") }, { "config", { "*.lua", "!x" } }, "split")
	h.assert_equal({ glob().split("plain query") }, { "plain query", {} }, "no filter")
	h.assert_equal({ glob().split("  *.md") }, { "", { "*.md" } }, "filter alone")
end

function tests.globs_become_rg_arguments()
	h.assert_equal(glob().rg_args({ "*.lua", "!x" }), { "--glob", "*.lua", "--glob", "!x" }, "arguments")
end

function tests.a_glob_without_a_slash_matches_the_file_name_alone()
	local keep = glob().matcher({ "*.lua" })
	h.assert_equal(keep("deep/down/init.lua"), true, "matching name")
	h.assert_equal(keep("lua/init.txt"), false, "other name")
end

function tests.a_glob_with_a_slash_matches_the_path()
	local keep = glob().matcher({ "src/**" })
	h.assert_equal(keep("src/a/b.lua"), true, "inside")
	h.assert_equal(keep("lib/src.lua"), false, "outside")
end

function tests.exclusions_win_and_alone_keep_everything_else()
	local keep = glob().matcher({ "*.lua", "!test.lua" })
	h.assert_equal(keep("a/test.lua"), false, "excluded")
	h.assert_equal(keep("a/b.lua"), true, "included")
	h.assert_equal(glob().matcher({ "!*.md" })("a.txt"), true, "only an exclusion")
	h.assert_equal(glob().matcher({ "!*.md" })("a.md"), false, "excluded by itself")
end

function tests.a_half_typed_glob_filters_nothing()
	h.assert_equal(glob().matcher({ "[" })("anything"), true, "unparsed glob")
	h.assert_equal(glob().matcher({})("anything"), true, "no globs")
end

function tests.loading_on_first_require_runs_setup_once_and_keeps_one_module()
	local on_first_require = require("lib.on_first_require")
	local dir = h.temp_dir()
	vim.fn.mkdir(dir .. "/lua/fake/sub", "p")
	vim.fn.writefile({ "return { name = 'fake' }" }, dir .. "/lua/fake/init.lua")
	vim.fn.writefile({ "return { name = 'sub' }" }, dir .. "/lua/fake/sub/init.lua")
	vim.fn.writefile({ "return {}" }, dir .. "/lua/fakeother.lua")
	vim.opt.rtp:prepend(dir)
	local runs = 0
	on_first_require({ "fake" }, function()
		runs = runs + 1
		require("fake")
	end)

	require("fakeother")
	h.assert_equal(runs, 0, "a module with a similar name")
	local first = require("fake.sub")
	h.assert_equal(runs, 1, "first require")
	h.assert_equal(first.name, "sub", "submodule")
	h.assert_equal(require("fake.sub"), first, "same module")
	h.assert_equal(require("fake").name, "fake", "module loaded by setup")
	h.assert_equal(runs, 1, "later requires")
end

function tests.two_first_require_hooks_do_not_remove_each_other()
	local on_first_require = require("lib.on_first_require")
	local dir = h.temp_dir()
	vim.fn.mkdir(dir .. "/lua", "p")
	vim.fn.writefile({ "return 'one'" }, dir .. "/lua/hookone.lua")
	vim.fn.writefile({ "return 'two'" }, dir .. "/lua/hooktwo.lua")
	vim.opt.rtp:prepend(dir)
	local ran = {}
	on_first_require({ "hookone" }, function()
		table.insert(ran, "one")
	end)
	on_first_require({ "hooktwo" }, function()
		table.insert(ran, "two")
	end)

	h.assert_equal(require("hookone"), "one", "first module")
	h.assert_equal(require("hooktwo"), "two", "second module")
	h.assert_equal(ran, { "one", "two" }, "setups")
end

function tests.a_paired_motion_runs_each_way_and_repeats_with_the_last_direction()
	local motion_repeat = require("plugins.editor.motion_repeat")
	local repeatable = require("nvim-treesitter-textobjects.repeatable_move")
	local moves = {}
	local next_move, prev_move = motion_repeat.pair(function()
		table.insert(moves, "next")
	end, function()
		table.insert(moves, "prev")
	end)

	prev_move()
	repeatable.repeat_last_move()
	repeatable.repeat_last_move_opposite()
	next_move()

	h.assert_equal(moves, { "prev", "prev", "next", "next" }, "moves")
end

function tests.unchanged_ranges_fold_all_but_three_lines_around_each_change()
	local folds = require("plugins.editor.git_changes.folds")
	local hunk = { added = { start = 10, count = 2 }, removed = { start = 10, count = 1 } }
	h.assert_equal(
		folds.unchanged_ranges({ hunk }, 30),
		{ { first = 1, last = 6 }, { first = 15, last = 30 } },
		"ranges"
	)
end

function tests.unchanged_ranges_treat_a_deletion_as_one_line_and_merge_close_changes()
	local folds = require("plugins.editor.git_changes.folds")
	local deletion = { added = { start = 0, count = 0 }, removed = { start = 1, count = 1 } }
	h.assert_equal(folds.unchanged_ranges({ deletion }, 10), { { first = 5, last = 10 } }, "deletion at the top")
	local near = { added = { start = 7, count = 1 }, removed = { start = 7, count = 1 } }
	local nearer = { added = { start = 12, count = 1 }, removed = { start = 12, count = 1 } }
	h.assert_equal(folds.unchanged_ranges({ near, nearer }, 15), { { first = 1, last = 3 } }, "overlapping context")
end

function tests.no_changes_fold_the_whole_file_and_a_change_at_the_end_leaves_no_tail()
	local folds = require("plugins.editor.git_changes.folds")
	h.assert_equal(folds.unchanged_ranges({}, 5), { { first = 1, last = 5 } }, "nothing changed")
	local last = { added = { start = 5, count = 1 }, removed = { start = 5, count = 1 } }
	h.assert_equal(folds.unchanged_ranges({ last }, 5), { { first = 1, last = 1 } }, "change at the end")
end

function tests.a_loading_server_is_reported_until_it_says_it_is_ready()
	local readiness = require("plugins.lsp.readiness")
	local client = { id = 7, config = { capabilities = { experimental = { serverStatusNotification = true } } } }
	h.assert_equal(readiness.is_loading(client), true, "before it reports")
	readiness.on_server_status(nil, { quiescent = false }, { client_id = 7 })
	h.assert_equal(readiness.is_loading(client), true, "still busy")
	readiness.on_server_status(nil, { quiescent = true }, { client_id = 7 })
	h.assert_equal(readiness.is_loading(client), false, "ready")
	vim.api.nvim_exec_autocmds("LspDetach", { data = { client_id = 7 } })
	h.assert_equal(readiness.is_loading(client), true, "after a restart")
end

function tests.a_server_that_reports_no_status_is_never_loading()
	local readiness = require("plugins.lsp.readiness")
	h.assert_equal(readiness.is_loading({ id = 1, config = { capabilities = {} } }), false, "no capability")
	h.assert_equal(readiness.is_loading({ id = 2, config = {} }), false, "no capabilities")
end

function tests.when_loaded_holds_a_lookup_back_while_a_server_loads()
	local readiness = require("plugins.lsp.readiness")
	local notified = h.capture_notifications()
	local client = {
		id = 9,
		name = "rust-analyzer",
		config = { capabilities = { experimental = { serverStatusNotification = true } } },
	}
	local lookups = 0
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.get_clients = function()
		return { client }
	end
	local lookup = readiness.when_loaded(function()
		lookups = lookups + 1
	end)

	lookup()
	h.assert_equal(lookups, 0, "while loading")
	h.assert_contains(notified, "rust-analyzer is still loading", "message")
	readiness.on_server_status(nil, { quiescent = true }, { client_id = 9 })
	lookup()
	h.assert_equal(lookups, 1, "once ready")
end

return tests
