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

---@alias build.Status "building" | "running" | "passed" | "failed" | "stopped"

---@type table<build.Status, {annote: string, hl: string}>
local STATUS_STYLE = {
	building = { annote = "Building", hl = "DiagnosticInfo" },
	running = { annote = "Running", hl = "DiagnosticInfo" },
	passed = { annote = "Passed", hl = "DiagnosticOk" },
	failed = { annote = "Failed", hl = "DiagnosticError" },
	stopped = { annote = "Stopped", hl = "DiagnosticWarn" },
}

local FIDGET_GROUP = "build"

--- Shown by fidget in the corner, so long commands never trigger a "Press ENTER" prompt.
---@param msg string
---@param level integer|string vim.log.levels value, or a highlight group for the annote
---@param opts table fidget notification options
local function fidget_notify(msg, level, opts)
	local fidget = require("fidget")
	fidget.notification.set_config(FIDGET_GROUP, {
		name = "Build",
		icon = vim.g.have_nerd_font and "\u{f085}" or nil,
		group_style = "Title",
	}, false)
	fidget.notify(msg, level, vim.tbl_extend("force", { group = FIDGET_GROUP }, opts))
end

--- Each status replaces the previous one, so a build shows as one item that changes state.
---@param status build.Status
---@param msg string
local function notify_status(status, msg)
	local style = STATUS_STYLE[status]
	fidget_notify(msg, style.hl, {
		key = "status",
		annote = style.annote,
		ttl = status == "building" and math.huge or 0,
	})
end

--- Keeps status lines short enough that the coloured status word stays on screen.
---@param cmd string
---@return string
local function short_command(cmd)
	local max = 40
	if vim.fn.strchars(cmd) <= max then
		return cmd
	end
	return vim.fn.strcharpart(cmd, 0, max - 1) .. "…"
end

---@param msg string
---@param level integer vim.log.levels value
local function notify(msg, level)
	fidget_notify(msg, level, {})
end

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
	local line_count = vim.api.nvim_buf_line_count(buf)

	-- Only a window already at the end tails the output; scrolling back to read an
	-- earlier error would otherwise be yanked forward by the next line the build prints.
	local tailing = {}
	for _, win in ipairs(vim.fn.win_findbuf(buf)) do
		tailing[win] = vim.api.nvim_win_get_cursor(win)[1] >= line_count
	end

	local is_empty = line_count == 1 and vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1] == ""
	vim.api.nvim_buf_set_lines(buf, is_empty and 0 or -1, -1, false, lines)

	local last_line = vim.api.nvim_buf_line_count(buf)
	for win, at_end in pairs(tailing) do
		if at_end and vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_set_cursor(win, { last_line, 0 })
		end
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
	local title = "Build: " .. command.cmd
	vim.fn.setqflist({}, " ", {
		title = title,
		lines = lines,
		efm = "%D" .. ROOT_LINE_PREFIX .. "%f," .. errorformat_for(command.compiler),
	})

	local root_line = ROOT_LINE_PREFIX .. root
	local items = vim.tbl_filter(function(item)
		return item.text ~= root_line
	end, vim.fn.getqflist())
	vim.fn.setqflist({}, "r", { title = title, items = items })

	local valid = 0
	for _, item in ipairs(items) do
		if item.valid == 1 then
			valid = valid + 1
		end
	end
	return valid
end

---@param cmd string
---@param result vim.SystemCompleted
---@param issues integer quickfix entries loaded, zero for a plain run
---@param seconds number
local function report(cmd, result, issues, seconds)
	local elapsed = ("%.1fs"):format(seconds)
	if result.signal ~= 0 then
		notify_status("stopped", short_command(cmd))
	elseif result.code == 0 then
		local suffix = issues > 0 and (", %d quickfix entries"):format(issues) or ""
		notify_status("passed", ("%s (%s%s)"):format(short_command(cmd), elapsed, suffix))
	else
		local hint = issues > 0 and "" or "; <leader>mo shows the output"
		notify_status("failed", ("%s (exit %d, %s%s)"):format(short_command(cmd), result.code, elapsed, hint))
		if issues > 0 then
			-- Guarded, or a failing run would surface whatever a past build left behind.
			-- Builds finish in the background, so the cursor stays where it was typing.
			local focused = vim.api.nvim_get_current_win()
			vim.cmd("botright cwindow")
			if vim.api.nvim_win_is_valid(focused) then
				vim.api.nvim_set_current_win(focused)
			end
		end
	end
end

--- Streams a command's output into the output buffer and reports how it ended.
---@param project build.Project
---@param cmd string
---@param status build.Status shown while it is still going
---@param collect_issues fun(output: string[]): integer quickfix entries loaded
local function start_command(project, cmd, status, collect_issues)
	if active_run then
		notify(("Already running: %s (<leader>mk stops it)"):format(short_command(active_run.cmd)), vim.log.levels.WARN)
		return
	end

	local buf = reset_output_buffer()
	local output = {}
	local on_lines = function(lines)
		vim.list_extend(output, lines)
		append_output(buf, lines)
	end
	local started = vim.uv.hrtime()

	notify_status(status, ("%s in %s"):format(short_command(cmd), vim.fn.fnamemodify(project.root, ":t")))
	local job = vim.system({ vim.o.shell, vim.o.shellcmdflag, cmd }, {
		cwd = project.root,
		text = true,
		detach = true,
		stdout = line_stream(on_lines),
		stderr = line_stream(on_lines),
	}, function(result)
		vim.schedule(function()
			active_run = nil
			report(cmd, result, collect_issues(output), (vim.uv.hrtime() - started) / 1e9)
		end)
	end)
	active_run = { job = job, cmd = cmd }
end

---@param project build.Project
---@param command build.Command
local function run(project, command)
	start_command(project, command.cmd, "building", function(output)
		return load_quickfix(project.root, output, command)
	end)
end

--- A program's own output is not compiler diagnostics, so none of it reaches quickfix.
---@param project build.Project
---@param cmd string
local function execute(project, cmd)
	start_command(project, cmd, "running", function()
		return 0
	end)
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
		state.custom = store.remember(state.custom, cmd)
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
		notify("No build output yet", vim.log.levels.INFO)
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
---@param signal "sigterm"|"sigkill"
local function signal_process_group(run_to_stop, signal)
	vim.uv.kill(-run_to_stop.job.pid, signal)
end

--- How long a command gets to exit on its own before it is killed outright.
local STOP_GRACE_MS = 3000

local function stop()
	if not active_run then
		notify("No build is running", vim.log.levels.INFO)
		return
	end
	local stopping = active_run
	signal_process_group(stopping, "sigterm")
	-- active_run is only cleared when the process is reaped, so one that ignores
	-- SIGTERM would leave every later build refusing to start for the whole session.
	vim.defer_fn(function()
		if active_run == stopping then
			signal_process_group(stopping, "sigkill")
		end
	end, STOP_GRACE_MS)
end

vim.api.nvim_create_autocmd("VimLeavePre", {
	desc = "Stop a running build when Neovim exits",
	group = vim.api.nvim_create_augroup("build-runner", { clear = true }),
	callback = function()
		if active_run then
			signal_process_group(active_run, "sigterm")
		end
	end,
})

---@param project build.Project
---@param state build.ProjectState
---@param cmd string
local function select_and_execute(project, state, cmd)
	state.run = cmd
	state.run_custom = store.remember(state.run_custom, cmd)
	store.save(project.root, state)
	execute(project, cmd)
end

---@param project build.Project
---@param state build.ProjectState
local function prompt_run_command(project, state)
	vim.ui.input({ prompt = "Run command: ", default = state.run }, function(input)
		if not input or vim.trim(input) == "" then
			return
		end
		select_and_execute(project, state, vim.trim(input))
	end)
end

--- Nothing is detected for a run the way build systems are, so the first run of a
--- project asks for the command and every later one reuses it.
local function execute_selected()
	local project = current_project()
	local state = store.load(project.root)
	if state.run then
		execute(project, state.run)
	else
		prompt_run_command(project, state)
	end
end

local function pick_run_command()
	local project = current_project()
	local state = store.load(project.root)
	if #state.run_custom == 0 then
		prompt_run_command(project, state)
		return
	end

	---@type build.PickItem[]
	local items = {}
	for _, cmd in ipairs(state.run_custom) do
		table.insert(items, { cmd = cmd, saved = true })
	end
	table.insert(items, { saved = false })

	vim.ui.select(items, {
		prompt = ("Run command (%s)"):format(vim.fn.fnamemodify(project.root, ":~")),
		---@param item build.PickItem
		format_item = function(item)
			if not item.cmd then
				return "Custom..."
			end
			return (item.cmd == state.run and "* " or "  ") .. item.cmd
		end,
	}, function(item)
		if not item then
			return
		end
		if item.cmd then
			select_and_execute(project, state, item.cmd)
		else
			prompt_run_command(project, state)
		end
	end)
end

vim.keymap.set("n", "<leader>mb", build, { desc = "Build project with its selected command" })
vim.keymap.set("n", "<leader>mp", pick, { desc = "Build pick or type a command for this project" })
vim.keymap.set("n", "<leader>mr", execute_selected, { desc = "Build run the project's run command" })
vim.keymap.set("n", "<leader>mP", pick_run_command, { desc = "Build pick or type the run command" })
vim.keymap.set("n", "<leader>mo", toggle_output, { desc = "Build toggle output window" })
vim.keymap.set("n", "<leader>mk", stop, { desc = "Build stop the running command" })
