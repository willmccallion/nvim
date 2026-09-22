--- Live grep pickers backed directly by rg.
--- Each keystroke reruns rg, so the globs after a double space and the
--- changed-file list can narrow the search itself rather than its results.

local glob = require("plugins.editor.telescope.glob")

local M = {}

--- Live grep that reruns rg on every keystroke with the args `rg_args_for` builds.
---@param title string
---@param rg_args_for fun(prompt: string): string[]? nil skips the search; the pattern must follow "--"
local function live_rg_picker(title, rg_args_for)
	if vim.fn.executable("rg") == 0 then
		vim.notify(title .. " needs ripgrep on PATH", vim.log.levels.ERROR)
		return
	end

	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local make_entry = require("telescope.make_entry")

	pickers
		.new({}, {
			prompt_title = title,
			finder = finders.new_job(function(prompt)
				if not prompt or prompt == "" then
					return nil
				end
				local args = rg_args_for(prompt)
				if not args then
					return nil
				end
				return vim.list_extend({ "rg", "--vimgrep", "--smart-case" }, args)
			end, make_entry.gen_from_vimgrep({})),
			previewer = conf.grep_previewer({}),
			sorter = require("telescope.sorters").highlighter_only({}),
		})
		:find()
end

--- Modified and untracked files under the cwd, as cwd-relative paths.
---@return string[]? files nil when git fails (not a repo, no commits yet, ...)
local function git_changed_files()
	local diff_cmd = { "git", "diff", "--name-only", "--relative", "--diff-filter=ACMR", "HEAD" }
	local changed = vim.system(diff_cmd, { text = true }):wait()
	local untracked = vim.system({ "git", "ls-files", "--others", "--exclude-standard" }, { text = true }):wait()
	for _, result in ipairs({ changed, untracked }) do
		if result.code ~= 0 then
			vim.notify("git failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
			return nil
		end
	end
	return vim.split(changed.stdout .. untracked.stdout, "\n", { trimempty = true })
end

function M.grep_changed_files()
	local files = git_changed_files()
	if not files then
		return
	end
	if #files == 0 then
		vim.notify("No changed files", vim.log.levels.INFO)
		return
	end

	live_rg_picker("Grep Changed Files", function(prompt)
		return vim.list_extend({ "--", prompt }, files)
	end)
end

function M.grep_with_glob_filter()
	live_rg_picker("Live Grep (pattern  *.glob)", function(prompt)
		local pattern, globs = glob.split(prompt)
		if pattern == "" then
			return nil
		end
		return vim.list_extend(glob.rg_args(globs), { "--", pattern })
	end)
end

function M.grep_current_file_directory()
	local dir = vim.fn.expand("%:p:h")
	require("telescope.builtin").live_grep({
		search_dirs = { dir },
		prompt_title = "Grep in " .. vim.fn.fnamemodify(dir, ":~:."),
	})
end

return M
