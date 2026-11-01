--- Runs tests/*_test.lua against the installed plugins: nvim -l tests/run.lua [filter]
--- The filter matches a test's name or its file.
--- With $TEST_COVERAGE_DIR set to an empty folder, it reports the lines they ran.
--- Each file returns a table of tests named after their behaviour. Every test gets
--- its own nvim and an empty $HOME, since a panel and its autocmds last a session.

local root = vim.fs.dirname(vim.fs.dirname(vim.fs.abspath(arg[0])))
package.path = vim.fs.joinpath(root, "tests", "?.lua;") .. package.path

--- Only what the tested modules require, so the tests start without the whole config.
local PLUGINS = { "gitsigns.nvim", "nvim-web-devicons", "nvim-treesitter", "nvim-treesitter-textobjects" }

--- Pins and build commands are kept under stdpath("data"), which must not be the real one.
local function isolate_home()
	local home = vim.fn.tempname()
	vim.fn.mkdir(home, "p")
	vim.env.HOME = home
	for _, name in ipairs({ "DATA", "STATE", "CACHE", "CONFIG" }) do
		vim.env["XDG_" .. name .. "_HOME"] = vim.fs.joinpath(home, name:lower())
	end
	vim.fn.mkdir(vim.fn.stdpath("data"), "p")
end

---@param file string
---@param name string
local function run_one(file, name)
	vim.env.TEST_REAL_DATA_HOME = vim.fs.dirname(vim.fn.stdpath("data"))
	local plugin_dir = vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt")
	for _, plugin in ipairs(PLUGINS) do
		vim.opt.rtp:prepend(vim.fs.joinpath(plugin_dir, plugin))
	end
	vim.opt.rtp:prepend(root)
	vim.g.mapleader = " "
	isolate_home()
	vim.env.GIT_CONFIG_GLOBAL = "/dev/null"
	vim.env.GIT_CONFIG_SYSTEM = "/dev/null"
	if vim.env.TEST_COVERAGE_DIR then
		require("coverage").start(root)
	end

	local ok, err = xpcall(dofile(file)[name], debug.traceback)
	if vim.env.TEST_COVERAGE_DIR then
		require("coverage").save(vim.env.TEST_COVERAGE_DIR)
	end
	if not ok then
		io.stderr:write(tostring(err), "\n")
		vim.cmd.cquit()
	end
	vim.cmd.quitall({ bang = true })
end

---@param file string
---@param name string
---@return boolean
local function passes(file, name)
	local command = { vim.v.progpath, "-l", arg[0], "--one", file, name }
	local result = vim.system(command, { text = true }):wait(60000)
	if result.code == 0 then
		print("[ OK ] " .. name)
		return true
	end
	print("[FAIL] " .. name)
	print(result.stderr)
	return false
end

local function run_all(filter)
	local failed, total = 0, 0
	for _, file in ipairs(vim.fn.glob(vim.fs.joinpath(root, "tests", "*_test.lua"), false, true)) do
		local names = vim.tbl_keys(dofile(file))
		table.sort(names)
		for _, name in ipairs(names) do
			if not filter or name:find(filter, 1, true) or file:find(filter, 1, true) then
				total = total + 1
				if not passes(file, name) then
					failed = failed + 1
				end
			end
		end
	end
	print(("%d passed, %d failed"):format(total - failed, failed))
	if vim.env.TEST_COVERAGE_DIR then
		require("coverage").report(root, vim.env.TEST_COVERAGE_DIR)
	end
	if failed > 0 or total == 0 then
		vim.cmd.cquit()
	end
	vim.cmd.quitall({ bang = true })
end

if arg[1] == "--one" then
	run_one(arg[2], arg[3])
else
	run_all(arg[1])
end
