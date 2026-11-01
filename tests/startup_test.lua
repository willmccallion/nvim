--- The whole config, started as it really runs, with the installed plugins.

local h = require("helpers")

local ROOT = vim.fs.dirname(vim.fs.dirname(debug.getinfo(1, "S").source:sub(2)))

---@param probe string[] lines of Lua run after startup; what they print comes back
---@param file? string opened at startup
---@return {code: integer, stdout: string, stderr: string}
local function start(probe, file)
	local dir = h.temp_dir()
	vim.fn.writefile(probe, dir .. "/probe.lua")
	local command = { vim.v.progpath, "--headless", "-i", "NONE", "-u", ROOT .. "/init.lua" }
	vim.list_extend(command, { "--cmd", "set rtp^=" .. ROOT })
	if file then
		table.insert(command, file)
	end
	vim.list_extend(command, { "-c", "luafile " .. dir .. "/probe.lua", "-c", "qa!" })
	local config = vim.fn.stdpath("config")
	vim.fn.mkdir(config, "p")
	vim.uv.fs_copyfile(ROOT .. "/nvim-pack-lock.json", config .. "/nvim-pack-lock.json")
	local env = { XDG_DATA_HOME = vim.env.TEST_REAL_DATA_HOME }
	return vim.system(command, { env = env, text = true, cwd = dir }):wait(30000)
end

local tests = {}

function tests.the_whole_config_starts_without_a_single_error()
	local result = start({})

	h.assert_equal(result.code, 0, "exit status")
	h.assert_equal(result.stderr, "", "startup errors")
end

function tests.a_real_file_opens_without_errors()
	local path = h.temp_dir() .. "/a.lua"
	vim.fn.writefile({ "local a = 1", "return a" }, path)

	local result = start({}, path)

	h.assert_equal(result.code, 0, "exit status")
	h.assert_equal(result.stderr, "", "errors")
end

function tests.heavy_plugins_wait_until_they_are_used()
	local result = start({
		"for _, name in ipairs({ 'cmp', 'luasnip', 'nvim-autopairs', 'telescope', 'dap', 'dap-view' }) do",
		"  io.write(name, '=', tostring(package.loaded[name] ~= nil), ' ')",
		"end",
	})

	h.assert_equal(
		vim.trim(result.stderr .. result.stdout),
		"cmp=false luasnip=false nvim-autopairs=false telescope=false dap=false dap-view=false",
		"loaded plugins"
	)
end

function tests.telescope_is_set_up_the_first_time_it_is_required()
	local result = start({
		"local conf = require('telescope.config').values",
		"io.write(conf.layout_strategy, ' ', tostring(require('telescope').extensions.fzf ~= nil))",
	})

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "horizontal true", "configured")
end

function tests.the_debugger_is_set_up_the_first_time_it_is_required()
	local result = start({
		"local dap = require('dap')",
		"io.write(tostring(dap.adapters.lldb ~= nil), ' ', #dap.configurations.c)",
	})

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "true 3", "configured")
end

function tests.completion_loads_on_the_first_insert_with_its_keys_mapped()
	local result = start({
		"vim.api.nvim_exec_autocmds('InsertEnter', {})",
		"io.write(tostring(package.loaded.cmp ~= nil), ' ', tostring(package.loaded['nvim-autopairs'] ~= nil))",
	})

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "true true", "loaded")
end

function tests.every_documented_group_of_keys_exists()
	local result = start({
		"for _, keys in ipairs({ ' gd', ' sf', ' dd', ' mb', ' a', ' rp', ' tt', ' cy', ' bo', ' wm', '<C-Up>' }) do",
		"  if vim.fn.maparg(keys, 'n') == '' then io.write('missing ', keys, ' ') end",
		"end",
	})

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "", "missing keys")
end

function tests.the_config_s_commands_exist()
	local result = start({
		"for _, name in ipairs({ 'GitChanges', 'DebugProgram', 'Update', 'Q', 'LspInfo' }) do",
		"  if vim.fn.exists(':' .. name) ~= 2 then io.write('missing ', name, ' ') end",
		"end",
	})

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "", "missing commands")
end

return tests
