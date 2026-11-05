--- Assertions and small tools shared by the tests.

local M = {}

local ROOT = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))

function M.assert_equal(actual, expected, what)
	if not vim.deep_equal(actual, expected) then
		error(("%s: expected %s, got %s"):format(what, vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

function M.assert_contains(lines, wanted, what)
	for _, line in ipairs(lines) do
		if line:find(wanted, 1, true) then
			return
		end
	end
	error(("%s: no line has %q in %s"):format(what, wanted, vim.inspect(lines)), 2)
end

function M.refute_contains(lines, unwanted, what)
	for _, line in ipairs(lines) do
		if line:find(unwanted, 1, true) then
			error(("%s: %q should be absent from %s"):format(what, unwanted, vim.inspect(lines)), 2)
		end
	end
end

---@return string[] every message passed to vim.notify from now on
function M.capture_notifications()
	local seen = {}
	---@diagnostic disable-next-line: duplicate-set-field
	vim.notify = function(message)
		table.insert(seen, message)
	end
	return seen
end

---@param lhs string
---@param mode? string
function M.press(lhs, mode)
	vim.fn.maparg(vim.keycode(lhs), mode or "n", false, true).callback()
end

---@return string a new empty folder
function M.temp_dir()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	return dir
end

--- vim.pack reads the plugin pins from the config folder, which the tests keep empty.
local function copy_pack_lock()
	local config = vim.fn.stdpath("config")
	vim.fn.mkdir(config, "p")
	vim.uv.fs_copyfile(ROOT .. "/nvim-pack-lock.json", config .. "/nvim-pack-lock.json")
end

--- The whole config, started as it really runs, with the installed plugins.
---@param probe string[] lines of Lua run after startup; what they print comes back
---@param file? string opened at startup
---@param env? table<string, string> added to the environment
---@return {code: integer, stdout: string, stderr: string}
function M.start_config(probe, file, env)
	local dir = M.temp_dir()
	vim.fn.writefile(probe, dir .. "/probe.lua")
	local command = { vim.v.progpath, "--headless", "-i", "NONE", "-u", ROOT .. "/init.lua" }
	vim.list_extend(command, { "--cmd", "set rtp^=" .. ROOT })
	if file then
		table.insert(command, file)
	end
	vim.list_extend(command, { "-c", "luafile " .. dir .. "/probe.lua", "-c", "qa!" })
	copy_pack_lock()
	local full_env = vim.tbl_extend("force", { XDG_DATA_HOME = vim.env.TEST_REAL_DATA_HOME }, env or {})
	return vim.system(command, { env = full_env, text = true, cwd = dir }):wait(30000)
end

--- The whole config in a terminal, as it really runs with its UI, for what only runs under
--- one: returns the terminal's job (stop it with vim.fn.jobstop), an RPC channel to that nvim
--- once it has started, and a function giving everything it has drawn so far.
---@return {job: integer, channel: integer, drawn: fun(): string}
function M.start_config_in_terminal()
	copy_pack_lock()
	local dir = M.temp_dir()
	local socket = dir .. "/nvim.sock"
	local command =
		{ vim.v.progpath, "--listen", socket, "-i", "NONE", "-u", ROOT .. "/init.lua", "--cmd", "set rtp^=" .. ROOT }
	local drawn = {}
	local job = vim.fn.jobstart(command, {
		pty = true,
		on_stdout = function(_, data)
			vim.list_extend(drawn, data)
		end,
		width = 80,
		height = 24,
		cwd = dir,
		env = { XDG_DATA_HOME = vim.env.TEST_REAL_DATA_HOME, TERM = "xterm-256color" },
	})
	assert(
		vim.wait(10000, function()
			return vim.uv.fs_stat(socket) ~= nil
		end, 20),
		"nvim never listened on " .. socket
	)
	local channel = vim.fn.sockconnect("pipe", socket, { rpc = true })
	assert(
		vim.wait(10000, function()
			return vim.rpcrequest(channel, "nvim_get_vvar", "vim_did_enter") == 1
		end, 20),
		"nvim never finished starting"
	)
	return {
		job = job,
		channel = channel,
		drawn = function()
			return table.concat(drawn, "\n")
		end,
	}
end

return M
