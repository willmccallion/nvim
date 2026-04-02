--- @module plugins.editor.telescope
--- @brief Fuzzy finder via Telescope with fzf-native and ui-select extensions.
--- Find files, smart grep (supports *.ext prefix for filetype filtering),
--- git log, changed-file grep, directory-scoped grep, marks, and more
--- under the <leader>s prefix.

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

pcall(telescope.load_extension, "fzf")
pcall(telescope.load_extension, "ui-select")

local builtin = require("telescope.builtin")
local map = vim.keymap.set
map("n", "<leader>sf", builtin.find_files, { desc = "Search find files by name" })
map("n", "<leader>sw", builtin.grep_string, { desc = "Search for word under cursor in all files" })
map("n", "<leader>sk", require("telescope.builtin").keymaps, { desc = "Search keymaps and keyboard shortcuts" })
map("n", "<leader>/", builtin.buffers, { desc = "Switch between open buffers" })
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
end, { desc = "Fuzzy search text in current buffer" })

map("n", "<leader>so", builtin.oldfiles, { desc = "Search recently opened files" })
map("n", "<leader>sq", builtin.search_history, { desc = "Search previous search queries" })

-- Grep only in git-changed files
map("n", "<leader>sc", function()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local make_entry = require("telescope.make_entry")

	local changed = vim.fn.systemlist("git diff --name-only --diff-filter=ACMR HEAD")
	local untracked = vim.fn.systemlist("git ls-files --others --exclude-standard")
	local files = {}
	for _, f in ipairs(changed) do table.insert(files, f) end
	for _, f in ipairs(untracked) do table.insert(files, f) end

	if #files == 0 then
		vim.notify("No changed files", vim.log.levels.INFO)
		return
	end

	pickers.new({}, {
		prompt_title = "Grep Changed Files",
		finder = finders.new_job(function(prompt)
			if not prompt or prompt == "" then return nil end
			return vim.iter({ "rg", "--vimgrep", "--smart-case", prompt, unpack(files) }):totable()
		end, make_entry.gen_from_vimgrep({})),
		previewer = conf.grep_previewer({}),
		sorter = require("telescope.sorters").highlighter_only({}),
	}):find()
end, { desc = "Search grep only in git changed files" })

-- Git log with diff preview
map("n", "<leader>sl", builtin.git_commits, { desc = "Search git log commits" })

-- Smart grep: supports "*.rs pattern" syntax for filetype filtering
map("n", "<leader>sg", function()
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local make_entry = require("telescope.make_entry")

	pickers.new({}, {
		prompt_title = "Live Grep (supports *.ext prefix)",
		finder = finders.new_job(function(prompt)
			if not prompt or prompt == "" then return nil end
			local glob, query = prompt:match("^(%*%.%S+)%s+(.+)$")
			if glob and query then
				return { "rg", "--vimgrep", "--smart-case", "--glob", glob, query }
			end
			return { "rg", "--vimgrep", "--smart-case", prompt }
		end, make_entry.gen_from_vimgrep({})),
		previewer = conf.grep_previewer({}),
		sorter = require("telescope.sorters").highlighter_only({}),
	}):find()
end, { desc = "Search grep text (supports *.ext prefix to filter filetype)" })

-- Grep in current file's directory
map("n", "<leader>s.", function()
	local dir = vim.fn.expand("%:p:h")
	builtin.live_grep({ search_dirs = { dir }, prompt_title = "Grep in " .. vim.fn.fnamemodify(dir, ":~:.") })
end, { desc = "Search grep in current file directory" })

-- Marks
map("n", "<leader>sM", builtin.marks, { desc = "Search marks and jump to them" })
