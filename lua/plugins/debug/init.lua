--- The debugger's keys and :DebugProgram. All keys live under <leader>d; function
--- keys are avoided because tmux binds F1-F9. Everything else is in dap.lua, which
--- waits until something requires dap or dap-view.

vim.pack.add({
	"https://github.com/mfussenegger/nvim-dap",
	"https://github.com/igorlfs/nvim-dap-view",
})

require("lib.on_first_require")({ "dap", "dap-view" }, function()
	require("plugins.debug.dap")
end)

--- Going through dap keeps the load in one order: dap.lua itself requires dap.
---@return table
local function debugger()
	require("dap")
	return require("plugins.debug.dap")
end

---@param module "dap"|"dap-view"
---@param name string
---@return fun()
local function call(module, name)
	return function()
		require(module)[name]()
	end
end

vim.api.nvim_create_user_command("DebugProgram", function(opts)
	debugger().debug_program(opts.fargs)
end, { nargs = "+", complete = "file", desc = "Debug a built program with breakpoints at file:line" })

vim.api.nvim_create_user_command("DebugCore", function(opts)
	debugger().debug_core(opts.fargs)
end, { nargs = "+", complete = "file", desc = "Open a program's core file where it crashed" })

local map = vim.keymap.set
map("n", "<leader>dd", function()
	debugger().continue_or_start()
end, { desc = "Debug continue, or start what this project debugged last" })
map("n", "<leader>dD", function()
	debugger().start_by_picking()
end, { desc = "Debug start, picking the program and arguments" })
map("n", "<leader>dn", call("dap", "step_over"), { desc = "Debug step over (next line)" })
map("n", "<leader>di", call("dap", "step_into"), { desc = "Debug step into function" })
map("n", "<leader>do", call("dap", "step_out"), { desc = "Debug step out of function" })
map("n", "<leader>db", call("dap", "toggle_breakpoint"), { desc = "Debug toggle breakpoint" })
map("n", "<leader>dB", function()
	vim.ui.input({ prompt = "Breakpoint condition: " }, function(condition)
		if condition and condition ~= "" then
			require("dap").set_breakpoint(condition)
		end
	end)
end, { desc = "Debug set conditional breakpoint" })
--- Prints and carries on rather than stopping. {} interpolates an expression,
--- so "i = {i}, len = {vec.len}" reads like the printf you would have added.
map("n", "<leader>dp", function()
	vim.ui.input({ prompt = "Log point message: " }, function(message)
		if message and message ~= "" then
			require("dap").set_breakpoint(nil, nil, message)
		end
	end)
end, { desc = "Debug set log point (prints without stopping)" })
map("n", "<leader>dC", call("dap", "run_to_cursor"), { desc = "Debug continue to cursor" })
map("n", "<leader>dl", call("dap", "run_last"), { desc = "Debug rerun last configuration" })
map("n", "<leader>dr", call("dap", "restart"), { desc = "Debug restart session" })
map("n", "<leader>dq", call("dap", "terminate"), { desc = "Debug stop session" })
map("n", "<leader>du", call("dap-view", "toggle"), { desc = "Debug toggle view panel" })
map({ "n", "x" }, "<leader>dw", call("dap-view", "add_expr"), { desc = "Debug watch expression under cursor" })
map("n", "<leader>dh", call("dap-view", "hover"), { desc = "Debug inspect value under cursor" })
map("n", "<leader>dv", function()
	require("plugins.debug.variables").pick()
end, { desc = "Debug search variables in the stopped frame" })
map("n", "<leader>dt", function()
	require("plugins.debug.types").show_frame()
end, { desc = "Debug show every variable in the frame with its type" })
map({ "n", "x" }, "<leader>dT", function()
	require("plugins.debug.types").show_type_definition()
end, { desc = "Debug show the definition of the type under cursor" })
map("n", "<leader>dV", call("dap-view", "virtual_text_toggle"), { desc = "Debug toggle inline variable values" })
