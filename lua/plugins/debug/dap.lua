--- Debugging via nvim-dap with the lldb-dap adapter and nvim-dap-view UI.
--- Launches or attaches to C, C++ and Rust programs. All keys live under
--- <leader>d; function keys are avoided because tmux binds F1-F9.
--- The debug view opens and closes automatically with the session.

vim.pack.add({
	"https://github.com/mfussenegger/nvim-dap",
	"https://github.com/igorlfs/nvim-dap-view",
})

local dap = require("dap")
local dap_view = require("dap-view")

dap_view.setup({
	auto_toggle = true,
	-- Scope trees are wide and shallow, and the bottom is already the build output's.
	windows = { size = 0.35, position = "right" },
})

--- The DAP adapter binary is lldb-dap, which was called lldb-vscode before LLVM 18.
--- Neither `lldb` nor `lld` speaks DAP, so only these two names are worth trying.
local LLDB_DAP_NAMES = { "lldb-dap", "lldb-vscode" }

---@param paths string[]
---@return string? the highest LLVM version among them
local function newest_llvm(paths)
	local newest, newest_version = nil, -1
	for _, path in ipairs(paths) do
		local version = tonumber(path:match("llvm%-(%d+)")) or 0
		if version > newest_version then
			newest, newest_version = path, version
		end
	end
	return newest
end

--- Distributions often ship the adapter only inside the LLVM tree rather than on
--- PATH. Set vim.g.lldb_dap_command to skip the search on a machine that hides it
--- somewhere else.
---@return string?
local function find_lldb_dap()
	if vim.g.lldb_dap_command then
		return vim.g.lldb_dap_command
	end
	for _, name in ipairs(LLDB_DAP_NAMES) do
		if vim.fn.executable(name) == 1 then
			return name
		end
	end
	local in_llvm_tree = {}
	for _, name in ipairs(LLDB_DAP_NAMES) do
		vim.list_extend(in_llvm_tree, vim.fn.glob("/usr/lib/llvm-*/bin/" .. name, false, true))
	end
	return newest_llvm(in_llvm_tree)
end

--- Resolved per session, so installing the adapter does not need a restart.
dap.adapters.lldb = function(callback)
	local command = find_lldb_dap()
	if not command then
		vim.notify(
			("No DAP adapter found. Install LLVM's %s, or set vim.g.lldb_dap_command to its path."):format(
				table.concat(LLDB_DAP_NAMES, " or ")
			),
			vim.log.levels.ERROR
		)
		return
	end
	callback({ type = "executable", command = command, name = "lldb" })
end

---@type string?
local last_program = nil

--- Where freshly built binaries usually live: Cargo's target/debug or a CMake build/ dir.
---@return string
local function default_program_dir()
	local buf_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(0))
	local target = vim.fs.find("target", { upward = true, type = "directory", path = buf_dir })[1]
	if target then
		return vim.fs.joinpath(target, "debug") .. "/"
	end
	local build = vim.fs.find("build", { upward = true, type = "directory", path = buf_dir })[1]
	if build then
		return build .. "/"
	end
	return vim.fn.getcwd() .. "/"
end

--- Asks through vim.ui.input from inside dap's config resolution, which is
--- synchronous. dap resumes a returned suspended coroutine with its own and then
--- waits, so the answer is delivered by resuming that one from the callback.
---@param opts {prompt: string, default?: string, completion?: string}
---@param parse fun(answer: string?): any
---@return thread
local function prompt_in_coroutine(opts, parse)
	return coroutine.create(function(dap_co)
		vim.ui.input(opts, function(answer)
			coroutine.resume(dap_co, parse(answer))
		end)
	end)
end

---@return thread
local function prompt_program()
	return prompt_in_coroutine({
		prompt = "Executable: ",
		default = last_program or default_program_dir(),
		completion = "file",
	}, function(program)
		if not program or program == "" then
			return dap.ABORT
		end
		last_program = vim.fn.fnamemodify(program, ":p")
		return last_program
	end)
end

---@return thread
local function prompt_args()
	return prompt_in_coroutine({ prompt = "Arguments: " }, function(args)
		return require("dap.utils").splitstr(args or "")
	end)
end

--- Loads rustc's LLDB formatters so Vec, String, Option, etc. display readably.
---@return string[]
local function rust_init_commands()
	if vim.fn.executable("rustc") == 0 then
		return {}
	end
	local sysroot = vim.trim(vim.fn.system({ "rustc", "--print", "sysroot" }))
	if vim.v.shell_error ~= 0 then
		return {}
	end
	local lookup = vim.fs.joinpath(sysroot, "lib", "rustlib", "etc", "lldb_lookup.py")
	return { ('command script import "%s"'):format(lookup) }
end

--- A step that leaves the current frame otherwise stops wherever it lands, and
--- libc and other code built without debug info have only disassembly to show.
local STEP_AVOID_COMMANDS = {
	"settings set target.process.thread.step-in-avoid-nodebug true",
	"settings set target.process.thread.step-out-avoid-nodebug true",
}

---@param extra_commands? fun(): string[]
---@return fun(): string[]
local function init_commands(extra_commands)
	return function()
		local commands = vim.list_extend({}, STEP_AVOID_COMMANDS)
		if extra_commands then
			vim.list_extend(commands, extra_commands())
		end
		return commands
	end
end

---@param extra_commands? fun(): string[] run after the shared step-avoid settings
---@return dap.Configuration[]
local function lldb_configurations(extra_commands)
	local commands = init_commands(extra_commands)
	return {
		{
			name = "Launch executable",
			type = "lldb",
			request = "launch",
			program = prompt_program,
			cwd = "${workspaceFolder}",
			initCommands = commands,
		},
		{
			name = "Launch executable with arguments",
			type = "lldb",
			request = "launch",
			program = prompt_program,
			args = prompt_args,
			cwd = "${workspaceFolder}",
			initCommands = commands,
		},
		{
			name = "Attach to running process",
			type = "lldb",
			request = "attach",
			pid = require("dap.utils").pick_process,
			initCommands = commands,
		},
	}
end

dap.configurations.c = lldb_configurations()
dap.configurations.cpp = lldb_configurations()
dap.configurations.rust = lldb_configurations(rust_init_commands)

vim.fn.sign_define("DapBreakpoint", { text = "●", texthl = "DiagnosticError" })
vim.fn.sign_define("DapBreakpointCondition", { text = "◆", texthl = "DiagnosticWarn" })
vim.fn.sign_define("DapBreakpointRejected", { text = "○", texthl = "DiagnosticHint" })
vim.fn.sign_define("DapStopped", { text = "→", texthl = "DiagnosticOk", linehl = "Visual" })

--- A program's own output and its exit status only reach the REPL view, which
--- auto_toggle closes along with the session, so a crash or a bad invocation would
--- otherwise look identical to a clean run.
local EXIT_LISTENER = "report-failed-exit"

---@type integer?
local last_exit_code = nil

dap.listeners.after.event_exited[EXIT_LISTENER] = function(_, body)
	last_exit_code = body and body.exitCode
end

dap.listeners.after.event_terminated[EXIT_LISTENER] = function()
	local code = last_exit_code
	last_exit_code = nil
	if not code or code == 0 then
		return
	end
	vim.notify(("Debug: process exited with status %d"):format(code), vim.log.levels.WARN)
	-- Runs after dap-view's own before-listener has closed the panel.
	dap_view.open()
	dap_view.show_view("repl")
end

local map = vim.keymap.set
map("n", "<leader>dd", dap.continue, { desc = "Debug start or continue" })
map("n", "<leader>dn", dap.step_over, { desc = "Debug step over (next line)" })
map("n", "<leader>di", dap.step_into, { desc = "Debug step into function" })
map("n", "<leader>do", dap.step_out, { desc = "Debug step out of function" })
map("n", "<leader>db", dap.toggle_breakpoint, { desc = "Debug toggle breakpoint" })
map("n", "<leader>dB", function()
	vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
		if condition and condition ~= "" then
			dap.set_breakpoint(condition)
		end
	end)
end, { desc = "Debug set conditional breakpoint" })
map("n", "<leader>dc", dap.run_to_cursor, { desc = "Debug run to cursor" })
map("n", "<leader>dl", dap.run_last, { desc = "Debug rerun last configuration" })
map("n", "<leader>dr", dap.restart, { desc = "Debug restart session" })
map("n", "<leader>dq", dap.terminate, { desc = "Debug stop session" })
map("n", "<leader>du", dap_view.toggle, { desc = "Debug toggle view panel" })
map({ "n", "x" }, "<leader>dw", dap_view.add_expr, { desc = "Debug watch expression under cursor" })
map("n", "<leader>dh", dap_view.hover, { desc = "Debug inspect value under cursor" })
map("n", "<leader>dv", function()
	require("plugins.debug.variables").pick()
end, { desc = "Debug search variables in the stopped frame" })
map("n", "<leader>dV", dap_view.virtual_text_toggle, { desc = "Debug toggle inline variable values" })
