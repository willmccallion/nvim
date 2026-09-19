--- Fuzzy finder via Telescope with fzf-native and ui-select extensions.
--- Find files, smart grep (supports *.ext prefix for filetype filtering),
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

telescope.load_extension("fzf")
telescope.load_extension("ui-select")

local builtin = require("telescope.builtin")
local map = vim.keymap.set
map("n", "<leader>sf", builtin.find_files, { desc = "Search find files by name" })
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
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local make_entry = require("telescope.make_entry")

	local files = git_changed_files()
	if not files then
		return
	end
	if #files == 0 then
		vim.notify("No changed files", vim.log.levels.INFO)
		return
	end

	pickers
		.new({}, {
			prompt_title = "Grep Changed Files",
			finder = finders.new_job(function(prompt)
				if not prompt or prompt == "" then
					return nil
				end
				return vim.iter({ "rg", "--vimgrep", "--smart-case", "--", prompt, unpack(files) }):totable()
			end, make_entry.gen_from_vimgrep({})),
			previewer = conf.grep_previewer({}),
			sorter = require("telescope.sorters").highlighter_only({}),
		})
		:find()
end, { desc = "Git grep only in changed files" })

map("n", "<leader>gl", builtin.git_commits, { desc = "Git log commits with diff preview" })

map("n", "<leader>sg", function()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local make_entry = require("telescope.make_entry")

	pickers
		.new({}, {
			prompt_title = "Live Grep (supports *.ext prefix)",
			finder = finders.new_job(function(prompt)
				if not prompt or prompt == "" then
					return nil
				end
				local glob, query = prompt:match("^(%*%.%S+)%s+(.+)$")
				if glob and query then
					return { "rg", "--vimgrep", "--smart-case", "--glob", glob, "--", query }
				end
				return { "rg", "--vimgrep", "--smart-case", "--", prompt }
			end, make_entry.gen_from_vimgrep({})),
			previewer = conf.grep_previewer({}),
			sorter = require("telescope.sorters").highlighter_only({}),
		})
		:find()
end, { desc = "Search grep text (supports *.ext prefix to filter filetype)" })

map("n", "<leader>s.", function()
	local dir = vim.fn.expand("%:p:h")
	builtin.live_grep({ search_dirs = { dir }, prompt_title = "Grep in " .. vim.fn.fnamemodify(dir, ":~:.") })
end, { desc = "Search grep in current file directory" })

map("n", "<leader>sm", builtin.marks, { desc = "Search marks and jump to them" })
