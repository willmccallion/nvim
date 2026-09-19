--- Asynchronous project build runner feeding the quickfix list.
--- Detects Cargo/CMake/Make from the current buffer, runs the project's selected
--- command in the background, and loads compiler errors into quickfix.
--- The chosen command and any custom commands are remembered per project.

local detect = require("plugins.coding.build.detect")
local store = require("plugins.coding.build.store")

---@class (private) build.Run
---@field job vim.SystemObj
---@field cmd string

---@type build.Run?
local active_run = nil

---@type integer?
local output_buf = nil

local ROOT_LINE_PREFIX = "build-root: "

---@return string
local function current_dir()
	local name = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or name == "" then
		return vim.fn.getcwd()
	end
	return vim.fs.dirname(name)
end

---@param dir string
---@return build.DirListing
local function list_markers(dir)
	local files = {}
	for _, file in ipairs(detect.marker_files) do
		if vim.uv.fs_stat(vim.fs.joinpath(dir, file)) then
			files[file] = true
		end
	end
	return { dir = dir, files = files }
end

--- Walks from the current buffer's directory up to the git root (or filesystem root).
---@return build.Project
local function current_project()
	local start = current_dir()
	local git_root = vim.fs.root(start, ".git")

	local listings = { list_markers(start) }
	if start ~= git_root then
		for dir in vim.fs.parents(start) do
			table.insert(listings, list_markers(dir))
			if dir == git_root then
				break
			end
		end
	end

	return detect.project(listings, git_root or vim.fn.getcwd())
end

---@type table<string, string>
local errorformat_cache = {}

--- make's "*** [target] Error N" lines name recipe files, not the failing source.
---@type table<string, string>
local ERRORFORMAT_PREFIX = { gcc = "%-G%.%#make%.%#: ***%.%#," }

---@param compiler? string
---@return string
local function errorformat_for(compiler)
	if not compiler then
		return vim.go.errorformat
	end
	if not errorformat_cache[compiler] then
		local scratch = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_call(scratch, function()
			vim.cmd.compiler(compiler)
			errorformat_cache[compiler] = (ERRORFORMAT_PREFIX[compiler] or "") .. vim.bo.errorformat
		end)
		vim.api.nvim_buf_delete(scratch, { force = true })
	end
	return errorformat_cache[compiler]
end

--- Custom commands have no known compiler; assume the project's own tooling.
---@param project build.Project
---@param cmd string
---@return build.Command
local function resolve_command(project, cmd)
	local detected = detect.commands(project)
	for _, command in ipairs(detected) do
		if command.cmd == cmd then
			return command
		end
	end
	return { cmd = cmd, compiler = detected[1] and detected[1].compiler }
end

---@return integer
local function reset_output_buffer()
	if not (output_buf and vim.api.nvim_buf_is_valid(output_buf)) then
		output_buf = vim.api.nvim_create_buf(false, true)
		vim.api.nvim_buf_set_name(output_buf, "build://output")
		vim.bo[output_buf].bufhidden = "hide"
	end
	vim.api.nvim_buf_set_lines(output_buf, 0, -1, false, {})
	return output_buf
end

---@param buf integer
---@param lines string[]
local function append_output(buf, lines)
	if not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	local is_empty = vim.api.nvim_buf_line_count(buf) == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
	vim.api.nvim_buf_set_lines(buf, is_empty and 0 or -1, -1, false, lines)
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		vim.api.nvim_win_set_cursor(win, { vim.api.nvim_buf_line_count(buf), 0 })
	end
end

--- Returns a vim.system stream handler that emits whole lines on the main loop.
---@param on_lines fun(lines: string[])
---@return fun(err?: string, data?: string)
local function line_stream(on_lines)
	local partial = ""
	return function(_, data)
		local lines
		if data then
			lines = vim.split(partial .. data, "\n", { plain = true })
			partial = table.remove(lines)
		elseif partial ~= "" then
			lines = { partial }
			partial = ""
		end
		if lines and #lines > 0 then
			vim.schedule(function()
				on_lines(lines)
			end)
		end
	end
end

--- The synthetic first line makes %D resolve relative paths against the project root.
---@param root string
---@param output string[]
---@param command build.Command
---@return integer valid_entries
local function load_quickfix(root, output, command)
	local lines = { ROOT_LINE_PREFIX .. root }
	vim.list_extend(lines, output)
	vim.fn.setqflist({}, " ", {
		title = "Build: " .. command.cmd,
		lines = lines,
		efm = "%D" .. ROOT_LINE_PREFIX .. "%f," .. errorformat_for(command.compiler),
	})
	local valid = 0
	for _, item in ipairs(vim.fn.getqflist()) do
		if item.valid == 1 then
			valid = valid + 1
		end
	end
	return valid
end

---@param command build.Command
---@param result vim.SystemCompleted
---@param issues integer
---@param seconds number
local function report(command, result, issues, seconds)
	local elapsed = ("%.1fs"):format(seconds)
	if result.signal ~= 0 then
		vim.notify(("Build stopped: %s"):format(command.cmd), vim.log.levels.WARN)
	elseif result.code == 0 then
		local suffix = issues > 0 and (", %d quickfix entries"):format(issues) or ""
		vim.notify(("Build passed: %s (%s%s)"):format(command.cmd, elapsed, suffix), vim.log.levels.INFO)
	else
		local hint = issues > 0 and "" or "; <leader>mo shows the output"
		vim.notify(
			("Build failed: %s (exit %d, %s%s)"):format(command.cmd, result.code, elapsed, hint),
			vim.log.levels.ERROR
		)
		vim.cmd("botright cwindow")
	end
end

---@param project build.Project
---@param command build.Command
local function run(project, command)
	if active_run then
		vim.notify(("Already running: %s (<leader>mk stops it)"):format(active_run.cmd), vim.log.levels.WARN)
		return
	end

	local buf = reset_output_buffer()
	local output = {}
	local on_lines = function(lines)
		vim.list_extend(output, lines)
		append_output(buf, lines)
	end
	local started = vim.uv.hrtime()

	vim.notify(("Building in %s: %s"):format(vim.fn.fnamemodify(project.root, ":~"), command.cmd))
	local job = vim.system({ vim.o.shell, vim.o.shellcmdflag, command.cmd }, {
		cwd = project.root,
		text = true,
		detach = true,
		stdout = line_stream(on_lines),
		stderr = line_stream(on_lines),
	}, function(result)
		vim.schedule(function()
			active_run = nil
			local issues = load_quickfix(project.root, output, command)
			report(command, result, issues, (vim.uv.hrtime() - started) / 1e9)
		end)
	end)
	active_run = { job = job, cmd = command.cmd }
end

---@param project build.Project
---@param state build.ProjectState
---@param cmd string
local function select_and_run(project, state, cmd)
	state.selected = cmd
	store.save(project.root, state)
	run(project, resolve_command(project, cmd))
end

---@param project build.Project
---@param state build.ProjectState
local function prompt_custom_command(project, state)
	vim.ui.input({ prompt = "Build command: ", default = state.selected }, function(input)
		if not input or vim.trim(input) == "" then
			return
		end
		local cmd = vim.trim(input)
		state.custom = vim.tbl_filter(function(existing)
			return existing ~= cmd
		end, state.custom)
		table.insert(state.custom, 1, cmd)
		select_and_run(project, state, cmd)
	end)
end

---@class (private) build.PickItem
---@field cmd? string nil for the "type a custom command" entry
---@field saved boolean

local function pick()
	local project = current_project()
	local state = store.load(project.root)

	local detected = detect.commands(project)
	local current = state.selected or (detected[1] and detected[1].cmd)

	---@type build.PickItem[]
	local items = {}
	local seen = {}
	for _, command in ipairs(detected) do
		table.insert(items, { cmd = command.cmd, saved = false })
		seen[command.cmd] = true
	end
	for _, cmd in ipairs(state.custom) do
		if not seen[cmd] then
			table.insert(items, { cmd = cmd, saved = true })
		end
	end
	table.insert(items, { saved = false })

	vim.ui.select(items, {
		prompt = ("Build command (%s, %s)"):format(
			project.kind or "no build system detected",
			vim.fn.fnamemodify(project.root, ":~")
		),
		---@param item build.PickItem
		format_item = function(item)
			if not item.cmd then
				return "Custom..."
			end
			local marker = item.cmd == current and "* " or "  "
			return marker .. item.cmd .. (item.saved and "  (saved)" or "")
		end,
	}, function(item)
		if not item then
			return
		end
		if item.cmd then
			select_and_run(project, state, item.cmd)
		else
			prompt_custom_command(project, state)
		end
	end)
end

local function build()
	local project = current_project()
	local state = store.load(project.root)
	local cmd = state.selected
	if not cmd then
		local detected = detect.commands(project)
		cmd = detected[1] and detected[1].cmd
	end
	if not cmd then
		pick()
		return
	end
	run(project, resolve_command(project, cmd))
end

local function toggle_output()
	if not (output_buf and vim.api.nvim_buf_is_valid(output_buf)) then
		vim.notify("No build output yet", vim.log.levels.INFO)
		return
	end
	local win = vim.fn.win_findbuf(output_buf)[1]
	if win then
		vim.api.nvim_win_close(win, false)
		return
	end
	vim.cmd("botright 15split")
	vim.api.nvim_win_set_buf(0, output_buf)
	vim.api.nvim_win_set_cursor(0, { vim.api.nvim_buf_line_count(output_buf), 0 })
end

--- Builds run in their own process group, so this also stops compilers the shell spawned.
---@param run_to_stop build.Run
local function kill_process_group(run_to_stop)
	vim.uv.kill(-run_to_stop.job.pid, "sigterm")
end

local function stop()
	if not active_run then
		vim.notify("No build is running", vim.log.levels.INFO)
		return
	end
	kill_process_group(active_run)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	desc = "Stop a running build when Neovim exits",
	group = vim.api.nvim_create_augroup("build-runner", { clear = true }),
	callback = function()
		if active_run then
			kill_process_group(active_run)
		end
	end,
})

vim.keymap.set("n", "<leader>mb", build, { desc = "Build project with its selected command" })
vim.keymap.set("n", "<leader>mp", pick, { desc = "Build pick or type a command for this project" })
vim.keymap.set("n", "<leader>mo", toggle_output, { desc = "Build toggle output window" })
vim.keymap.set("n", "<leader>mk", stop, { desc = "Build stop the running command" })
