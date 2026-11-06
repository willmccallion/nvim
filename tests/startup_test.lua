--- The whole config, started as it really runs, with the installed plugins.

local h = require("helpers")

local start = h.start_config

local tests = {}

function tests.the_whole_config_starts_without_a_single_error()
	local result = start({})

	h.assert_equal(result.code, 0, "exit status")
	h.assert_equal(result.stderr, "", "startup errors")
end

function tests.long_command_output_collapses_instead_of_waiting_for_a_key()
	local nvim = h.start_config_in_terminal()
	local before = #nvim.drawn()

	vim.rpcrequest(nvim.channel, "nvim_input", ':echo join(range(50), "\\n")<CR>')
	local function drawn_since()
		return nvim.drawn():sub(before + 1)
	end
	vim.wait(10000, function()
		return drawn_since():find("%[%+%d+%]") or drawn_since():find("-- More --", 1, true)
	end, 20)
	local mode = vim.rpcrequest(nvim.channel, "nvim_get_mode")
	vim.fn.jobstop(nvim.job)

	h.assert_equal(mode.blocking, false, "waiting for a key")
	h.assert_equal(drawn_since():find("%[%+%d+%]") ~= nil, true, "the [+n] count of the lines it hid")
end

--- Lua run in the config's nvim that opens <leader>sf on the files given (paths in the
--- working folder, each made first) and writes the rows it shows, one per line.
---@param paths string[]
---@param before_open? string[] Lua run once the files are made
---@return string[]
local function file_picker_probe(paths, before_open)
	local lines = {
		"for _, path in ipairs(vim.json.decode([=[" .. vim.json.encode(paths) .. "]=])) do",
		"  vim.fn.mkdir(vim.fs.dirname(path), 'p')",
		"  vim.fn.writefile({ 'x' }, path)",
		"end",
	}
	vim.list_extend(lines, before_open or {})
	vim.list_extend(lines, {
		"local state = require('telescope.actions.state')",
		"require('plugins.editor.telescope.files').find_files_with_glob_filter()",
		"local function rows()",
		"  local picker = state.get_current_picker(vim.api.nvim_get_current_buf())",
		"  return vim.tbl_filter(function(row) return vim.trim(row) ~= '' end,",
		"    vim.api.nvim_buf_get_lines(picker.results_bufnr, 0, -1, false))",
		"end",
		"vim.wait(5000, function() return #rows() >= " .. #paths .. " end, 20)",
	})
	table.insert(lines, "io.write(table.concat(rows(), '\\n'))")
	return lines
end

function tests.the_file_picker_shows_each_name_before_its_folder()
	local result = start(file_picker_probe({ "src/deep/parser.lua" }))

	h.assert_equal(result.stderr, "", "errors")
	h.assert_contains({ result.stdout }, "parser.lua src/deep", "row")
end

function tests.the_file_picker_marks_files_with_uncommitted_changes()
	local result = start(file_picker_probe({ "kept.lua", "edited.lua", "new.lua" }, {
		"local function git(...) vim.system({ 'git', '-c', 'user.name=t', '-c', 'user.email=t', ... }):wait() end",
		"git('init', '-q')",
		"git('add', 'kept.lua', 'edited.lua')",
		"git('commit', '-qm', 'first')",
		"vim.fn.writefile({ 'edited' }, 'edited.lua')",
	}))

	h.assert_equal(result.stderr, "", "errors")
	local rows = vim.split(result.stdout, "\n")
	--- A row starts with the picker's one-space indent, then the mark and a space.
	local function mark_of(name)
		for _, row in ipairs(rows) do
			if row:find(name, 1, true) then
				return row:sub(2, 3)
			end
		end
	end
	h.assert_equal(mark_of("edited.lua"), "M ", "changed file")
	h.assert_equal(mark_of("new.lua"), "? ", "untracked file")
	h.assert_equal(mark_of("kept.lua"), "  ", "unchanged file")
end

function tests.entering_a_file_remembers_the_visit()
	local result = start({
		"vim.fn.writefile({ 'x' }, 'seen.lua')",
		"vim.cmd.edit('seen.lua')",
		"local store = vim.fs.joinpath(vim.fn.stdpath('state'), 'file_visits.json')",
		"io.write(vim.tbl_keys(require('lib.json_file').read(store))[1] or 'nothing')",
	})

	h.assert_equal(result.stderr, "", "errors")
	h.assert_equal(vim.fs.basename(result.stdout), "seen.lua", "remembered file")
end

function tests.the_file_picker_puts_a_visited_file_nearest_the_prompt()
	local names = { "a.lua", "b.lua", "c.lua", "d.lua", "e.lua", "f.lua" }
	local result = start(file_picker_probe(names, {
		"local store = vim.fs.joinpath(vim.fn.stdpath('state'), 'file_visits.json')",
		"vim.fn.mkdir(vim.fs.dirname(store), 'p')",
		"require('lib.json_file').write(store, { [vim.fs.joinpath(vim.fn.getcwd(), 'd.lua')] = { os.time() } })",
	}))

	h.assert_equal(result.stderr, "", "errors")
	local rows = vim.split(result.stdout, "\n")
	h.assert_contains({ rows[#rows] }, "d.lua", "the row by the prompt")
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
		"for _, name in ipairs({ 'cmp', 'luasnip', 'nvim-autopairs', 'telescope', 'dap', 'dap-view', 'obsidian' }) do",
		"  io.write(name, '=', tostring(package.loaded[name] ~= nil), ' ')",
		"end",
	})

	h.assert_equal(
		vim.trim(result.stderr .. result.stdout),
		"cmp=false luasnip=false nvim-autopairs=false telescope=false dap=false dap-view=false obsidian=false",
		"loaded plugins"
	)
end

function tests.conflict_keys_work_and_semicolon_repeats_the_motion()
	local path = h.temp_dir() .. "/a.txt"
	vim.fn.writefile({
		"<<<<<<< a",
		"ours one",
		"=======",
		"theirs one",
		">>>>>>> b",
		"<<<<<<< a",
		"ours two",
		"=======",
		"theirs two",
		">>>>>>> b",
	}, path)

	local result = start({
		"vim.api.nvim_win_set_cursor(0, { 2, 0 })",
		"vim.cmd.normal(']n')",
		"io.write(vim.fn.line('.'), ' ')",
		"vim.cmd.normal(';')",
		"io.write(vim.fn.line('.'), ' ')",
		"vim.cmd.normal(' gt')",
		"io.write(vim.fn.line('$'), ' ', vim.fn.getline(1))",
	}, path)

	h.assert_equal(vim.trim(result.stderr .. result.stdout), "6 1 6 theirs one", "lines")
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
		"for _, name in ipairs({ 'GitChanges', 'DebugProgram', 'DebugCore', 'Update', 'Q', 'LspInfo' }) do",
		"  if vim.fn.exists(':' .. name) ~= 2 then io.write('missing ', name, ' ') end",
		"end",
	})

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "", "missing commands")
end

return tests
