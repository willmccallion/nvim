--- Fuzzy file finder whose file list is narrowed by the globs after a double space.
--- ripgrep applies those globs itself; fd and find, the listers used when it is
--- missing, list every file and the globs are matched here instead. Files you visit
--- often and lately rank higher (visits.lua), and changed ones carry git's letter.
--- The filters come back the next time the picker opens in the same folder.

local changed_marks = require("plugins.editor.telescope.changed_marks")
local glob = require("plugins.editor.telescope.glob")
local saved_filters = require("plugins.editor.telescope.saved_filters")
local visits = require("plugins.editor.telescope.visits")

local M = {}

---@class telescope.FileLister
---@field command fun(globs: string[]): string[] argv listing the candidate files
---@field entry_maker fun(opts: table, globs: string[]): fun(line: string): table?

--- Entry maker for the listers that cannot filter by glob themselves. Excluded
--- files are marked invalid rather than dropped: a nil entry would leave a hole
--- in the finder's result table, which the next keystroke iterates with ipairs.
---@param opts table
---@param globs string[]
local function glob_filtered_entry_maker(opts, globs)
	local entry_from_file = require("telescope.make_entry").gen_from_file(opts)
	local keep = glob.matcher(globs)

	return function(line)
		local path = (line:gsub("^%./", ""))
		local entry = entry_from_file(path)
		if entry and not keep(path) then
			entry.valid = false
		end
		return entry
	end
end

--- The lister to run, preferring the tools that skip ignored files themselves.
--- find lists anything the `-not -path */.*` telescope appends leaves behind,
--- so a node_modules or a target directory shows up in the results there.
---@return telescope.FileLister? lister nil when none of the three is installed
local function file_lister()
	if vim.fn.executable("rg") == 1 then
		return {
			command = function(globs)
				return vim.list_extend({ "rg", "--files", "--color", "never" }, glob.rg_args(globs))
			end,
			entry_maker = function(opts)
				return require("telescope.make_entry").gen_from_file(opts)
			end,
		}
	end
	if vim.fn.executable("fd") == 1 then
		return {
			command = function()
				return { "fd", "--type", "f", "--color", "never" }
			end,
			entry_maker = glob_filtered_entry_maker,
		}
	end
	if vim.fn.executable("find") == 1 then
		return {
			command = function()
				return { "find", ".", "-type", "f" }
			end,
			entry_maker = glob_filtered_entry_maker,
		}
	end
	return nil
end

function M.find_files_with_glob_filter()
	local lister = file_lister()
	if not lister then
		vim.notify("Listing files needs one of ripgrep, fd or find on PATH", vim.log.levels.ERROR)
		return
	end

	local builtin = require("telescope.builtin")
	local finders = require("telescope.finders")

	local folder = vim.fn.getcwd()
	-- Set here, not under pickers in setup: the entry maker below reads it from opts.
	local opts = { path_display = { "filename_first" } }
	local letters = changed_marks.letters(folder)
	---@param globs string[]
	local function entry_maker_for(globs)
		return changed_marks.marked(lister.entry_maker(opts, globs), letters)
	end
	local active_globs = saved_filters.load(folder)
	opts.entry_maker = entry_maker_for(active_globs)

	builtin.find_files(vim.tbl_extend("force", opts, {
		prompt_title = "Find Files (query  *.glob)",
		sorter = visits.favour_visited(require("telescope.config").values.file_sorter(opts), folder),
		find_command = lister.command(active_globs),
		default_text = #active_globs > 0 and "  " .. table.concat(active_globs, " ") or nil,
		on_input_filter_cb = function(prompt)
			local query, globs = glob.split(prompt)
			if vim.deep_equal(globs, active_globs) then
				return { prompt = query }
			end
			active_globs = globs
			local finder_opts = vim.tbl_extend("force", opts, { entry_maker = entry_maker_for(globs) })
			return { prompt = query, updated_finder = finders.new_oneshot_job(lister.command(globs), finder_opts) }
		end,
		attach_mappings = function(prompt_bufnr)
			vim.api.nvim_create_autocmd("BufWipeout", {
				desc = "Remember the file picker's filters for this folder",
				buffer = prompt_bufnr,
				once = true,
				callback = function()
					saved_filters.save(folder, active_globs)
				end,
			})
			if #active_globs > 0 then
				-- The saved filters fill the prompt; the search goes before them.
				vim.schedule(function()
					local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
					vim.api.nvim_win_set_cursor(picker.prompt_win, { 1, #picker.prompt_prefix })
				end)
			end
			return true
		end,
	}))
end

return M
