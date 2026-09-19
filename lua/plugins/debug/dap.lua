--- Debugging via nvim-dap with the lldb-dap adapter and nvim-dap-view UI.
--- Launches or attaches to C, C++ and Rust programs. All keys live under
--- <leader>D; function keys are avoided because tmux binds F1-F9.
--- The debug view opens and closes automatically with the session.

vim.pack.add({
	"https://github.com/mfussenegger/nvim-dap",
	"https://github.com/igorlfs/nvim-dap-view",
})

local dap = require("dap")
local dap_view = require("dap-view")

dap_view.setup({ auto_toggle = true })

dap.adapters.lldb = {
	type = "executable",
	command = "lldb-dap",
	name = "lldb",
}

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

---@return string|dap.Abort
local function prompt_program()
	local program = vim.fn.input({
		prompt = "Executable: ",
		default = last_program or default_program_dir(),
		completion = "file",
	})
	if program == "" then
		return dap.ABORT
	end
	last_program = vim.fn.fnamemodify(program, ":p")
	return last_program
end

---@return string[]
local function prompt_args()
	return require("dap.utils").splitstr(vim.fn.input("Arguments: "))
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

---@param init_commands? fun(): string[]
---@return dap.Configuration[]
local function lldb_configurations(init_commands)
	return {
		{
			name = "Launch executable",
			type = "lldb",
			request = "launch",
			program = prompt_program,
			cwd = "${workspaceFolder}",
			initCommands = init_commands,
		},
		{
			name = "Launch executable with arguments",
			type = "lldb",
			request = "launch",
			program = prompt_program,
			args = prompt_args,
			cwd = "${workspaceFolder}",
			initCommands = init_commands,
		},
		{
			name = "Attach to running process",
			type = "lldb",
			request = "attach",
			pid = require("dap.utils").pick_process,
			initCommands = init_commands,
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

local map = vim.keymap.set
map("n", "<leader>Dd", dap.continue, { desc = "Debug start or continue" })
map("n", "<leader>Dn", dap.step_over, { desc = "Debug step over (next line)" })
map("n", "<leader>Di", dap.step_into, { desc = "Debug step into function" })
map("n", "<leader>Do", dap.step_out, { desc = "Debug step out of function" })
map("n", "<leader>Db", dap.toggle_breakpoint, { desc = "Debug toggle breakpoint" })
map("n", "<leader>DB", function()
	dap.set_breakpoint(vim.fn.input("Breakpoint condition: "))
end, { desc = "Debug set conditional breakpoint" })
map("n", "<leader>Dc", dap.run_to_cursor, { desc = "Debug run to cursor" })
map("n", "<leader>Dl", dap.run_last, { desc = "Debug rerun last configuration" })
map("n", "<leader>Dr", dap.restart, { desc = "Debug restart session" })
map("n", "<leader>Dq", dap.terminate, { desc = "Debug stop session" })
map("n", "<leader>Du", dap_view.toggle, { desc = "Debug toggle view panel" })
map({ "n", "x" }, "<leader>Dw", dap_view.add_expr, { desc = "Debug watch expression under cursor" })
