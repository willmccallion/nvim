--- Fuzzy file finder whose file list is narrowed by the globs after a double space.

local glob = require("plugins.editor.telescope.glob")

local M = {}

function M.find_files_with_glob_filter()
	local builtin = require("telescope.builtin")
	local finders = require("telescope.finders")
	local make_entry = require("telescope.make_entry")

	local list_files = { "rg", "--files", "--color", "never" }
	local opts = {}
	opts.entry_maker = make_entry.gen_from_file(opts)
	local active_globs = {}

	builtin.find_files(vim.tbl_extend("force", opts, {
		prompt_title = "Find Files (query  *.glob)",
		find_command = list_files,
		on_input_filter_cb = function(prompt)
			local query, globs = glob.split(prompt)
			if vim.deep_equal(globs, active_globs) then
				return { prompt = query }
			end
			active_globs = globs
			local command = vim.list_extend(vim.deepcopy(list_files), glob.rg_args(globs))
			return { prompt = query, updated_finder = finders.new_oneshot_job(command, opts) }
		end,
	}))
end

return M
