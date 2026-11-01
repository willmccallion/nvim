--- The debugger's decisions, around a stand-in for nvim-dap: which adapter, which
--- program, what to do with one that can't be debugged, and how sessions end.

local h = require("helpers")

---@return table dap
local function stub_dap()
	local dap = {
		adapters = {},
		configurations = {},
		ABORT = { "abort" },
		runs = {},
		continued = 0,
		terminated = 0,
		active = nil,
		listeners = { after = { event_exited = {}, event_terminated = {}, event_initialized = {} } },
	}
	function dap.session()
		return dap.active
	end
	function dap.sessions()
		return dap.all_sessions or {}
	end
	function dap.run(config)
		table.insert(dap.runs, config)
	end
	function dap.continue()
		dap.continued = dap.continued + 1
	end
	function dap.terminate()
		dap.terminated = dap.terminated + 1
	end
	function dap.set_session(session)
		dap.current = session
	end
	package.loaded["dap"] = dap
	package.loaded["dap-view"] = {
		setup = function() end,
		open = function()
			dap.view_opened = true
		end,
		show_view = function(name)
			dap.view_shown = name
		end,
	}
	package.loaded["dap.utils"] = {
		pick_process = function() end,
		splitstr = function(text)
			return vim.split(text, " ", { trimempty = true })
		end,
	}
	package.loaded["dap.breakpoints"] = {
		set = function(_, bufnr, line)
			dap.breakpoint = { name = vim.api.nvim_buf_get_name(bufnr), line = line }
		end,
	}
	package.loaded["fidget"] = {
		notification = { set_config = function() end },
		notify = function() end,
	}
	return dap
end

--- Only the named programs are on PATH, each printing `output`.
---@param programs table<string, string>
local function path_with(programs)
	local bin = h.temp_dir()
	for name, output in pairs(programs) do
		vim.fn.writefile({ "#!/bin/sh", ("echo '%s'"):format(output) }, bin .. "/" .. name)
		vim.fn.setfperm(bin .. "/" .. name, "rwxr-xr-x")
	end
	vim.env.PATH = bin .. ":/usr/bin/false-not-a-dir"
end

---@return table module
local function load_debugger()
	return require("plugins.debug.dap")
end

--- dap hands a coroutine its own and waits to be resumed with the value.
---@param make_coroutine fun(): thread
---@return any
local function resolve(make_coroutine)
	local value
	local waiter = coroutine.create(function()
		value = coroutine.yield()
	end)
	coroutine.resume(waiter)
	coroutine.resume(make_coroutine(), waiter)
	return value
end

---@param flags string[]
---@return string
local function compiled(flags)
	local dir = h.temp_dir()
	vim.fn.writefile({ "int main(void) { return 0; }" }, dir .. "/a.c")
	local result = vim.system(vim.list_extend({ "cc", dir .. "/a.c", "-o", dir .. "/a" }, flags), { text = true }):wait()
	assert(result.code == 0, result.stderr)
	return dir .. "/a"
end

local tests = {}

function tests.debug_program_splits_breakpoints_from_program_arguments()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local debugger = load_debugger()
	local source = h.temp_dir() .. "/app.c"
	vim.fn.writefile({ "int x;", "int y;" }, source)

	debugger.debug_program({ "/bin/app", source .. ":2", "--", "--flag", "file:1" })

	h.assert_equal(dap.breakpoint, { name = source, line = 2 }, "breakpoint")
	h.assert_equal(dap.runs[1].program, "/bin/app", "program")
	h.assert_equal(dap.runs[1].args, { "--flag", "file:1" }, "arguments")
	h.assert_equal(dap.runs[1].type, "lldb", "adapter")
end

function tests.a_rust_project_loads_its_formatters_and_others_do_not()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "", rustc = "/sysroot" })
	local debugger = load_debugger()
	local root = h.temp_dir()
	vim.fn.writefile({ "[package]" }, root .. "/Cargo.toml")
	vim.cmd.edit(root .. "/main.rs")

	debugger.debug_program({ "/bin/app" })

	local commands = dap.runs[1].initCommands()
	h.assert_contains(commands, "/sysroot/lib/rustlib/etc/lldb_lookup.py", "formatters")
	h.assert_contains(commands, "step-in-avoid-nodebug true", "shared settings")

	vim.cmd.edit(h.temp_dir() .. "/main.c")
	debugger.debug_program({ "/bin/app" })
	h.refute_contains(dap.runs[2].initCommands(), "lldb_lookup", "a C project")
end

function tests.gdb_14_is_used_only_when_lldb_is_missing()
	local dap = stub_dap()
	path_with({ gdb = "GNU gdb (GDB) 14.2" })
	local debugger = load_debugger()

	debugger.debug_program({ "/bin/app" })

	h.assert_equal(dap.runs[1].type, "gdb", "adapter")
	h.assert_equal(dap.runs[1].initCommands, nil, "lldb settings")
	h.assert_equal(dap.adapters.gdb.args, { "-i", "dap" }, "gdb's adapter")
end

function tests.an_old_gdb_falls_back_to_lldb_and_starting_explains_why()
	local dap = stub_dap()
	path_with({ gdb = "GNU gdb (GDB) 12.1" })
	local notified = h.capture_notifications()
	local debugger = load_debugger()

	debugger.debug_program({ "/bin/app" })
	h.assert_equal(dap.runs[1].type, "lldb", "adapter")

	dap.adapters.lldb(function()
		error("there is no adapter to give")
	end)
	h.assert_contains(notified, "No DAP adapter found", "message")
	h.assert_contains(notified, "Found gdb 12, which predates its DAP support", "reason")
end

function tests.the_lldb_command_can_be_named_and_is_found_on_path()
	local dap = stub_dap()
	path_with({ ["lldb-vscode"] = "" })
	load_debugger()
	local given

	dap.adapters.lldb(function(adapter)
		given = adapter
	end)
	h.assert_equal(given.command, "lldb-vscode", "older name")

	vim.g.lldb_dap_command = "/opt/lldb-dap"
	dap.adapters.lldb(function(adapter)
		given = adapter
	end)
	h.assert_equal(given.command, "/opt/lldb-dap", "named command")
end

function tests.configurations_are_ready_as_soon_as_the_debugger_loads()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })

	load_debugger()

	h.assert_equal(#dap.configurations.c, 3, "C configurations")
	h.assert_equal(dap.configurations.cpp[3].request, "attach", "attach configuration")
	h.assert_equal(dap.configurations.rust[1].type, "lldb", "Rust configuration")
end

function tests.continuing_a_session_just_continues()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local debugger = load_debugger()
	dap.active = {}

	debugger.continue_or_start()

	h.assert_equal({ dap.continued, #dap.runs }, { 1, 0 }, "continued and runs")
end

function tests.starting_uses_what_this_project_debugged_last()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local notified = h.capture_notifications()
	local debugger = load_debugger()
	local root = h.temp_dir()
	vim.cmd.cd(root)
	require("plugins.coding.build").remember_debug_target(root, { program = "/bin/app", args = "-a -b" })

	debugger.continue_or_start()

	h.assert_equal(dap.runs[1].args, { "-a", "-b" }, "arguments")
	h.assert_contains({ dap.runs[1].name }, "/bin/app", "name")
	h.assert_contains(notified, "Debugging /bin/app -a -b", "message")
end

function tests.with_nothing_remembered_a_debuggable_language_asks_dap()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local debugger = load_debugger()
	vim.cmd.cd(h.temp_dir())
	vim.bo.filetype = "c"

	debugger.continue_or_start()

	h.assert_equal(dap.continued, 1, "asked dap")
end

function tests.another_file_type_offers_the_c_configurations()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local debugger = load_debugger()
	vim.cmd.cd(h.temp_dir())
	vim.bo.filetype = "gazprea"
	local offered
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.select = function(items, opts, on_choice)
		offered = vim.tbl_map(opts.format_item, items)
		on_choice(items[1])
	end

	debugger.start_by_picking()

	h.assert_equal(offered[1], "Launch executable", "first choice")
	h.assert_equal(dap.runs[1].name, "Launch executable", "ran the choice")
end

function tests.cancelling_the_choice_runs_nothing()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local debugger = load_debugger()
	vim.bo.filetype = "text"
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.select = function(_, _, on_choice)
		on_choice(nil)
	end

	debugger.start_by_picking()

	h.assert_equal(#dap.runs, 0, "runs")
end

function tests.a_second_start_is_refused_while_a_session_runs()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local notified = h.capture_notifications()
	local debugger = load_debugger()
	dap.active = {}

	debugger.start_by_picking()

	h.assert_contains(notified, "already running", "message")
	h.assert_equal(#dap.runs, 0, "runs")
end

--- The configuration a remembered program launches with.
---@param dap table
---@param debugger table
---@param program string
---@return table config
local function remembered_config(dap, debugger, program)
	local root = vim.fn.getcwd()
	require("plugins.coding.build").remember_debug_target(root, { program = program })
	debugger.continue_or_start()
	return dap.runs[#dap.runs]
end

function tests.a_program_with_debug_info_launches_straight_away()
	local dap = stub_dap()
	local real_path = vim.env.PATH
	local program = compiled({ "-g" })
	path_with({ ["lldb-dap"] = "" })
	local debugger = load_debugger()
	vim.cmd.cd(h.temp_dir())
	vim.env.PATH = real_path

	local config = remembered_config(dap, debugger, program)

	h.assert_equal(resolve(config.program), program, "program")
end

function tests.a_missing_program_aborts_with_a_makefile_hint()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local notified = h.capture_notifications()
	local debugger = load_debugger()
	local root = h.temp_dir()
	vim.fn.writefile({ "all:" }, root .. "/Makefile")
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/a.c")

	local config = remembered_config(dap, debugger, root .. "/missing")

	h.assert_equal(resolve(config.program), dap.ABORT, "result")
	h.assert_contains(notified, "does not exist", "problem")
	h.assert_contains(notified, "add -g -O0", "hint")
end

function tests.a_stripped_program_can_be_debugged_anyway_or_abandoned()
	local dap = stub_dap()
	local real_path = vim.env.PATH
	local program = compiled({ "-s" })
	path_with({ ["lldb-dap"] = "" })
	h.capture_notifications()
	local debugger = load_debugger()
	local root = h.temp_dir()
	vim.fn.writefile({ "all:" }, root .. "/Makefile")
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/a.c")
	vim.env.PATH = real_path
	local answer, prompt
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.select = function(_, opts, on_choice)
		prompt = opts.prompt
		on_choice(answer)
	end
	local config = remembered_config(dap, debugger, program)

	answer = "Debug it anyway"
	h.assert_equal(resolve(config.program), program, "anyway")
	h.assert_contains({ prompt }, "has no debug info", "prompt")

	answer = nil
	h.assert_equal(resolve(config.program), dap.ABORT, "abandoned")
end

function tests.a_cargo_project_offers_a_debug_build_and_uses_target_debug()
	local dap = stub_dap()
	local real_path = vim.env.PATH
	local release = compiled({ "-s" })
	local root = h.temp_dir()
	vim.fn.mkdir(root .. "/target/release", "p")
	vim.fn.mkdir(root .. "/target/debug", "p")
	vim.fn.writefile({ "[package]" }, root .. "/Cargo.toml")
	vim.uv.fs_copyfile(release, root .. "/target/release/app")
	vim.uv.fs_copyfile(compiled({ "-g" }), root .. "/target/debug/app")
	path_with({ ["lldb-dap"] = "", cargo = "" })
	vim.env.PATH = vim.env.PATH .. ":" .. real_path
	vim.o.shell, vim.o.shellcmdflag = "sh", "-c"
	local debugger = load_debugger()
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/main.rs")
	local offered
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.select = function(items, _, on_choice)
		offered = items
		on_choice(items[1])
	end
	local config = remembered_config(dap, debugger, root .. "/target/release/app")
	local program
	local waiter = coroutine.create(function()
		program = coroutine.yield()
	end)
	coroutine.resume(waiter)

	coroutine.resume(config.program(), waiter)
	vim.wait(5000, function()
		return program ~= nil
	end, 10)

	h.assert_equal(offered[1], "Build it with debug info, then debug it", "first choice")
	h.assert_equal(program, root .. "/target/debug/app", "debug build")
	h.assert_equal(
		require("plugins.coding.build").debug_target().program,
		root .. "/target/debug/app",
		"remembered for next time"
	)
end

function tests.a_failed_exit_is_reported_and_shows_the_program_s_output()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local notified = h.capture_notifications()
	load_debugger()

	dap.listeners.after.event_exited["report-failed-exit"](nil, { exitCode = 3 })
	dap.listeners.after.event_terminated["report-failed-exit"]()

	h.assert_contains(notified, "process exited with status 3", "message")
	h.assert_equal({ dap.view_opened, dap.view_shown }, { true, "repl" }, "view")
end

function tests.a_clean_exit_is_silent_and_does_not_leak_into_the_next_session()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	local notified = h.capture_notifications()
	load_debugger()

	dap.listeners.after.event_exited["report-failed-exit"](nil, { exitCode = 0 })
	dap.listeners.after.event_terminated["report-failed-exit"]()
	dap.listeners.after.event_exited["report-failed-exit"](nil, { exitCode = 1 })
	dap.listeners.after.event_terminated["report-failed-exit"]()
	dap.listeners.after.event_terminated["report-failed-exit"]()

	h.assert_equal(#notified, 1, "one failure reported once")
end

function tests.a_second_session_is_stopped_as_soon_as_it_starts()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	h.capture_notifications()
	load_debugger()
	local new_session = {}

	dap.all_sessions = { new_session }
	dap.listeners.after.event_initialized["one-session-only"](new_session)
	h.assert_equal(dap.terminated, 0, "the only session")

	dap.all_sessions = { {}, new_session }
	dap.listeners.after.event_initialized["one-session-only"](new_session)
	h.assert_equal({ dap.terminated, dap.current }, { 1, new_session }, "the second session")
end

function tests.the_debugger_s_signs_are_defined()
	stub_dap()
	path_with({ ["lldb-dap"] = "" })
	load_debugger()

	h.assert_equal(vim.fn.sign_getdefined("DapStopped")[1].linehl, "Visual", "stopped line")
	h.assert_equal(#vim.fn.sign_getdefined("DapBreakpoint"), 1, "breakpoint sign")
end

function tests.the_program_prompt_starts_in_the_project_s_build_folder()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	load_debugger()
	local root = h.temp_dir()
	vim.fn.mkdir(root .. "/target", "p")
	vim.fn.mkdir(root .. "/src", "p")
	vim.cmd.cd(root)
	vim.cmd.edit(root .. "/src/main.rs")
	local default
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.input = function(opts, on_confirm)
		default = opts.default
		on_confirm(nil)
	end

	local result = resolve(dap.configurations.c[1].program)

	h.assert_equal(default, root .. "/target/debug/", "starting folder")
	h.assert_equal(result, dap.ABORT, "cancelling aborts")
end

function tests.launching_with_arguments_remembers_them()
	local dap = stub_dap()
	path_with({ ["lldb-dap"] = "" })
	load_debugger()
	local root = h.temp_dir()
	vim.cmd.cd(root)
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.input = function(_, on_confirm)
		on_confirm("--one --two")
	end

	local args = resolve(dap.configurations.c[2].args)

	h.assert_equal(args, { "--one", "--two" }, "arguments")
	h.assert_equal(require("plugins.coding.build").debug_target().args, "--one --two", "remembered")
	h.assert_equal(dap.configurations.c[1].args(), {}, "launching without arguments")
	h.assert_equal(require("plugins.coding.build").debug_target().args, "", "cleared")
end

return tests
