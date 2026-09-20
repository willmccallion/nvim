--- Fuzzy finder via Telescope with fzf-native and ui-select extensions.
--- Find files and grep (both filter by glob after two spaces: `query  *.md`),
--- directory-scoped grep, marks, and more under <leader>s; git log and
--- changed-file grep under <leader>g.

vim.pack.add({
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	"https://github.com/nvim-telescope/telescope-ui-select.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
})

local telescope = require("telescope")
local actions = require("telescope.actions")

telescope.setup({
	defaults = {
		path_display = { "truncate" },
		mappings = {
			i = { ["<C-j>"] = actions.move_selection_next, ["<C-k>"] = actions.move_selection_previous },
		},
		layout_strategy = "horizontal",
		layout_config = { horizontal = { preview_width = 0.55 } },
		borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		prompt_prefix = vim.g.have_nerd_font and "  " or "> ",
		selection_caret = vim.g.have_nerd_font and " " or "-> ",
	},
	extensions = {
		["fzf"] = { override_generic_sorter = true, override_file_sorter = true, case_mode = "smart_case" },
		["ui-select"] = { require("telescope.themes").get_dropdown({}) },
	},
})

-- fzf-native is a compiled sorter. Without its library telescope still works on the
-- built-in one, so this must not raise: failing here would abort the rest of init.lua.
if not pcall(telescope.load_extension, "fzf") then
	-- Deferred so the message reaches fidget, which loads after this module.
	vim.schedule(function()
		vim.notify(
			"telescope-fzf-native is not built (needs make and a C compiler); using the slower built-in sorter",
			vim.log.levels.WARN
		)
	end)
end
telescope.load_extension("ui-select")

local builtin = require("telescope.builtin")
local map = vim.keymap.set
map("n", "<leader>sw", builtin.grep_string, { desc = "Search for word under cursor in all files" })
map("n", "<leader>sk", builtin.keymaps, { desc = "Search keymaps and keyboard shortcuts" })
map("n", "<leader>sb", builtin.buffers, { desc = "Search open buffers and switch" })
map("n", "<leader>sr", builtin.resume, { desc = "Search resume last search" })
map("n", "<leader>sh", builtin.help_tags, { desc = "Search help documentation" })
map("n", "<leader>sd", builtin.diagnostics, { desc = "Search diagnostics errors and warnings" })

map("n", "<leader>sn", function()
	builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search neovim config files" })

map("n", "<leader><leader>", function()
	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		winblend = 10,
		previewer = false,
	}))
end, { desc = "Search fuzzy text in current buffer" })

map("n", "<leader>so", builtin.oldfiles, { desc = "Search recently opened files" })
map("n", "<leader>sq", builtin.search_history, { desc = "Search previous search queries" })

--- Splits a prompt at its first double space into the query and the rg globs after it.
---@param prompt string
---@return string query
---@return string[] globs
local function split_glob_filter(prompt)
	local query, filter = prompt:match("^(.-)  (.*)$")
	if not query then
		return prompt, {}
	end
	return query, vim.split(filter, "%s+", { trimempty = true })
end

---@param globs string[]
---@return string[]
local function rg_glob_args(globs)
	local args = {}
	for _, glob in ipairs(globs) do
		vim.list_extend(args, { "--glob", glob })
	end
	return args
end

--- Fuzzy file finder whose file list is narrowed by the globs after a double space.
local function find_files_with_glob_filter()
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
			local query, globs = split_glob_filter(prompt)
			if vim.deep_equal(globs, active_globs) then
				return { prompt = query }
			end
			active_globs = globs
			local command = vim.list_extend(vim.deepcopy(list_files), rg_glob_args(globs))
			return { prompt = query, updated_finder = finders.new_oneshot_job(command, opts) }
		end,
	}))
end

map("n", "<leader>sf", find_files_with_glob_filter, { desc = "Search find files by name (query  *.glob)" })

--- Live grep that reruns rg on every keystroke with the args `rg_args_for` builds.
---@param title string
---@param rg_args_for fun(prompt: string): string[]? nil skips the search; the pattern must follow "--"
local function live_rg_picker(title, rg_args_for)
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

map("n", "<leader>gc", function()
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
end, { desc = "Git grep only in changed files" })

map("n", "<leader>gl", builtin.git_commits, { desc = "Git log commits with diff preview" })

map("n", "<leader>sg", function()
	live_rg_picker("Live Grep (pattern  *.glob)", function(prompt)
		local pattern, globs = split_glob_filter(prompt)
		if pattern == "" then
			return nil
		end
		return vim.list_extend(rg_glob_args(globs), { "--", pattern })
	end)
end, { desc = "Search grep text (pattern  *.glob)" })

map("n", "<leader>s.", function()
	local dir = vim.fn.expand("%:p:h")
	builtin.live_grep({ search_dirs = { dir }, prompt_title = "Grep in " .. vim.fn.fnamemodify(dir, ":~:.") })
end, { desc = "Search grep in current file directory" })

map("n", "<leader>sm", builtin.marks, { desc = "Search marks and jump to them" })
