--- What the debugger shows of a stopped program, against a stand-in session, and its keys.

local h = require("helpers")

---@param replies table<string, table|string> evaluate results by expression; a string is an error
---@return table session
local function stopped_session(replies)
	local session = { current_frame = { id = 1, scopes = {} }, config = { type = "lldb" }, asked = {} }
	function session.request(_, command, params, on_reply)
		table.insert(session.asked, params.expression or command)
		local reply = replies[params.expression or params.variablesReference]
		if type(reply) == "string" then
			on_reply({ message = reply })
		else
			on_reply(nil, reply)
		end
	end
	return session
end

---@param session table?
local function stub_dap(session)
	package.loaded["dap"] = {
		session = function()
			return session
		end,
	}
end

---@return table[] floats opened, each {lines, title}
local function stub_float()
	local shown = {}
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.util.open_floating_preview = function(lines, _, opts)
		table.insert(shown, { lines = lines, title = opts.title })
	end
	return shown
end

local LOOKUP = 'id = {0x1}, name = "Point", byte-size = 8, decl = point.h:3:8, compiler_type = "struct Point {\n}"'

local tests = {}

function tests.types_need_a_program_stopped_under_lldb()
	local notified = h.capture_notifications()
	stub_dap(nil)
	local types = require("plugins.debug.types")

	types.show_frame()
	h.assert_contains(notified, "not stopped at a breakpoint", "no session")

	local session = stopped_session({})
	session.config.type = "gdb"
	package.loaded["dap"].session = function()
		return session
	end
	types.show_frame()
	h.assert_contains(notified, "this session uses gdb", "another adapter")
end

function tests.the_frame_view_shows_each_variable_with_its_type()
	stub_dap(stopped_session({ ["`frame variable --show-types"] = { result = "(int) a = 1\n(int) b = 2\n" } }))
	local shown = stub_float()

	require("plugins.debug.types").show_frame()

	h.assert_equal(shown[1].lines, { "(int) a = 1", "(int) b = 2" }, "lines")
	h.assert_equal(shown[1].title, " Frame variables with types ", "title")
end

function tests.an_empty_frame_says_so()
	stub_dap(stopped_session({ ["`frame variable --show-types"] = { result = "" } }))
	local shown = stub_float()

	require("plugins.debug.types").show_frame()

	h.assert_equal(shown[1].lines, { "(no variables in this frame)" }, "lines")
end

function tests.a_failed_lldb_command_is_reported()
	local notified = h.capture_notifications()
	stub_dap(stopped_session({ ["`frame variable --show-types"] = "lost connection" }))

	require("plugins.debug.types").show_frame()

	h.assert_contains(notified, "failed: lost connection", "message")
end

local function buffer_with(word)
	vim.api.nvim_buf_set_lines(0, 0, -1, false, { word })
	vim.api.nvim_win_set_cursor(0, { 1, 0 })
end

function tests.the_type_of_the_variable_under_the_cursor_shows_its_definition()
	buffer_with("point")
	stub_dap(stopped_session({
		point = { type = "const Point &" },
		["`image lookup --type 'Point'"] = { result = LOOKUP },
	}))
	local shown = stub_float()

	require("plugins.debug.types").show_type_definition()

	h.assert_equal(shown[1].lines, { "struct Point {", "}", "", "// 8 bytes, declared at point.h:3:8" }, "lines")
	h.assert_equal(shown[1].title, " Point ", "title")
end

function tests.a_standard_library_type_points_at_the_frame_view_instead()
	local notified = h.capture_notifications()
	buffer_with("items")
	local session = stopped_session({ items = { type = "std::vector<int> &" } })
	stub_dap(session)

	require("plugins.debug.types").show_type_definition()

	h.assert_contains(notified, "is a standard library type", "message")
	h.assert_equal(#session.asked, 1, "no lookup")
end

function tests.a_template_is_retried_by_its_full_name()
	buffer_with("stack")
	stub_dap(stopped_session({
		stack = { type = "Stack<int>" },
		["`image lookup --type 'Stack<int>'"] = { result = "" },
		["`frame variable --raw-output --depth 0 --show-types stack"] = { result = "(Stack<int, Alloc>) stack = {}" },
		["`image lookup --type 'Stack<int, Alloc>'"] = { result = LOOKUP },
	}))
	local shown = stub_float()

	require("plugins.debug.types").show_type_definition()

	h.assert_equal(shown[1].title, " Stack<int, Alloc> ", "title")
end

function tests.a_type_found_under_no_name_is_reported()
	local notified = h.capture_notifications()
	buffer_with("thing")
	stub_dap(stopped_session({
		thing = { type = "Opaque" },
		["`image lookup --type 'Opaque'"] = { result = "" },
		["`frame variable --raw-output --depth 0 --show-types thing"] = { result = "(Opaque) thing = {}" },
	}))

	require("plugins.debug.types").show_type_definition()

	h.assert_contains(notified, "no definition found for type Opaque", "message")
end

function tests.a_word_that_is_no_variable_is_looked_up_as_a_type()
	buffer_with("Point")
	stub_dap(stopped_session({
		Point = "no such variable",
		["`image lookup --type 'Point'"] = { result = LOOKUP },
	}))
	local shown = stub_float()

	require("plugins.debug.types").show_type_definition()

	h.assert_equal(shown[1].title, " Point ", "title")
end

function tests.a_word_that_is_neither_variable_nor_type_says_so()
	local notified = h.capture_notifications()
	buffer_with("nonsense")
	stub_dap(stopped_session({
		nonsense = "no such variable",
		["`image lookup --type 'nonsense'"] = { result = "" },
	}))

	require("plugins.debug.types").show_type_definition()

	h.assert_contains(notified, "not a variable or a type", "message")
end

---@return table[] opened
local function stub_variable_picker()
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
		new_table = function(spec)
			return spec
		end,
	}
	package.loaded["telescope.actions"] = {}
	package.loaded["telescope.actions.state"] = {}
	package.loaded["telescope.pickers.entry_display"] = {
		create = function()
			return function() end
		end,
	}
	package.loaded["telescope.config"] = { values = { generic_sorter = function() end } }
	return opened
end

---@return table[] variables offered, by the time the scheduled picker opened
local function pick_variables(session)
	stub_dap(session)
	local opened = stub_variable_picker()
	require("plugins.debug.variables").pick()
	vim.wait(1000, function()
		return #opened > 0
	end, 5)
	return opened[1] and opened[1].finder.results or {}
end

function tests.variables_expand_one_level_and_leave_out_registers()
	local session = stopped_session({
		[7] = { variables = { { name = "x", value = "1", type = "int" }, { name = "[0]", value = "2" } } },
	})
	session.current_frame.scopes = {
		{
			name = "Locals",
			variables = {
				{ name = "p", value = "{...}", type = "Point", variablesReference = 7 },
				{ name = "n", value = "multi\n   line", evaluateName = "self.n" },
			},
		},
		{ name = "Registers", presentationHint = "registers", variables = { { name = "rax", value = "0" } } },
		{ name = "Costly", expensive = true, variables = { { name = "big", value = "0" } } },
	}

	local offered = pick_variables(session)

	h.assert_equal(
		vim.tbl_map(function(variable)
			return variable.expression
		end, offered),
		{ "p", "p.x", "p[0]", "self.n" },
		"expressions"
	)
	h.assert_equal(offered[4].value, "multi line", "one line value")
	h.assert_equal(offered[1].type, "Point", "type")
end

function tests.a_scope_not_fetched_yet_is_requested()
	local session = stopped_session({ [5] = { variables = { { name = "late", value = "1" } } } })
	session.current_frame.scopes = { { name = "Locals", variablesReference = 5 } }

	local offered = pick_variables(session)

	h.assert_equal(offered[1].expression, "late", "variable")
end

function tests.searching_variables_needs_a_stopped_frame_with_some()
	local notified = h.capture_notifications()
	stub_dap(nil)
	require("plugins.debug.variables").pick()
	h.assert_contains(notified, "No debug session stopped", "no session")

	pick_variables(stopped_session({}))
	vim.wait(200, function()
		return #notified > 1
	end, 5)
	h.assert_contains(notified, "No variables in the current frame", "no variables")
end

---@return table called names recorded
local function stub_debugger_for_keys()
	local called = {}
	local function recorder(name)
		return function(...)
			table.insert(called, { name, ... })
		end
	end
	package.loaded["dap"] = setmetatable({}, {
		__index = function(_, name)
			return recorder(name)
		end,
	})
	package.loaded["dap-view"] = setmetatable({}, {
		__index = function(_, name)
			return recorder("view." .. name)
		end,
	})
	package.loaded["plugins.debug.dap"] = {
		debug_program = recorder("debug_program"),
		continue_or_start = recorder("continue_or_start"),
		start_by_picking = recorder("start_by_picking"),
	}
	---@diagnostic disable-next-line: duplicate-set-field
	vim.pack.add = function() end
	require("plugins.debug")
	return called
end

function tests.each_debug_key_calls_what_it_says()
	local called = stub_debugger_for_keys()
	local keys = {
		["<leader>dd"] = "continue_or_start",
		["<leader>dD"] = "start_by_picking",
		["<leader>dn"] = "step_over",
		["<leader>di"] = "step_into",
		["<leader>do"] = "step_out",
		["<leader>db"] = "toggle_breakpoint",
		["<leader>dC"] = "run_to_cursor",
		["<leader>dl"] = "run_last",
		["<leader>dr"] = "restart",
		["<leader>dq"] = "terminate",
		["<leader>du"] = "view.toggle",
		["<leader>dw"] = "view.add_expr",
		["<leader>dh"] = "view.hover",
		["<leader>dV"] = "view.virtual_text_toggle",
	}
	for lhs, name in pairs(keys) do
		h.press(lhs)
		h.assert_equal(called[#called][1], name, lhs)
	end
end

function tests.a_conditional_breakpoint_or_log_point_needs_text()
	local called = stub_debugger_for_keys()
	local answer
	---@diagnostic disable-next-line: duplicate-set-field
	vim.ui.input = function(_, on_confirm)
		on_confirm(answer)
	end

	for _, lhs in ipairs({ "<leader>dB", "<leader>dp" }) do
		answer = ""
		h.press(lhs)
	end
	h.assert_equal(#called, 0, "with no text")

	answer = "x > 1"
	h.press("<leader>dB")
	h.assert_equal(called[1], { "set_breakpoint", "x > 1" }, "condition")
	answer = "i = {i}"
	h.press("<leader>dp")
	h.assert_equal(called[2][1], "set_breakpoint", "log point")
	h.assert_equal(called[2][4], "i = {i}", "log message")
end

function tests.debug_program_passes_every_word_on()
	local called = stub_debugger_for_keys()

	vim.cmd("DebugProgram /bin/app a.c:1 -- --flag")

	h.assert_equal(called[1], { "debug_program", { "/bin/app", "a.c:1", "--", "--flag" } }, "call")
end

---@param client_name string
local function attach_language_server(client_name)
	package.loaded["cmp_nvim_lsp"] = {
		default_capabilities = function()
			return {}
		end,
	}
	package.loaded["plugins.editor.telescope"] = {
		picker = function(name)
			return function()
				vim.g.last_picker = name
			end
		end,
	}
	require("plugins.lsp")
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.get_client_by_id = function()
		return {
			name = client_name,
			supports_method = function()
				return true
			end,
		}
	end
	vim.api.nvim_exec_autocmds("LspAttach", { buffer = 0, data = { client_id = 1 } })
end

local function buffer_key(lhs)
	return vim.fn.maparg(vim.keycode(lhs), "n", false, true).buffer == 1
end

function tests.attaching_a_server_sets_its_keys_in_that_buffer_only()
	attach_language_server("lua_ls")

	h.assert_equal(buffer_key("gd"), true, "gd")
	h.assert_equal(buffer_key("gr"), true, "gr")
	h.assert_equal(buffer_key("<leader>cr"), true, "rename")
	vim.cmd.enew()
	h.assert_equal(buffer_key("gd"), false, "another buffer")
end

function tests.only_clangd_gets_the_header_switch()
	attach_language_server("lua_ls")
	h.assert_equal(buffer_key("<leader>co"), false, "lua_ls")

	attach_language_server("clangd")
	h.assert_equal(buffer_key("<leader>co"), true, "clangd")
end

function tests.a_lookup_key_goes_to_its_telescope_picker()
	attach_language_server("lua_ls")
	---@diagnostic disable-next-line: duplicate-set-field
	vim.lsp.get_clients = function()
		return {}
	end

	h.press("gr")

	h.assert_equal(vim.g.last_picker, "lsp_references", "picker")
end

function tests.the_built_in_gr_keys_are_gone_so_gr_needs_no_wait()
	attach_language_server("lua_ls")

	h.assert_equal(vim.fn.maparg("grn", "n"), "", "grn")
	h.assert_equal(vim.fn.maparg("gra", "x"), "", "gra")
end

function tests.folding_follows_the_server_in_every_window_on_the_buffer()
	vim.cmd("vsplit")
	attach_language_server("lua_ls")

	for _, win in ipairs(vim.api.nvim_list_wins()) do
		h.assert_equal(vim.wo[win].foldexpr, "v:lua.vim.lsp.foldexpr()", "foldexpr")
	end
end

function tests.attaching_twice_does_not_double_the_reference_highlights()
	attach_language_server("lua_ls")
	attach_language_server("lua_ls")

	local autocmds = vim.api.nvim_get_autocmds({
		group = "lsp-document-highlight-buffer",
		buffer = 0,
		event = "CursorHold",
	})
	h.assert_equal(#autocmds, 1, "autocmds")
end

return tests
