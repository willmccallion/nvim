--- Fuzzy finder via Telescope with fzf-native and ui-select extensions.
--- Find files and grep (both filter by glob after two spaces: `query  *.md`),
--- directory-scoped grep, marks, and more under <leader>s; git log and
--- changed-file grep under <leader>g. The pickers themselves live beside this
--- file: glob filter parsing in glob.lua, the finders in files.lua and grep.lua,
--- and the grouped keymap picker in keymaps.lua.

vim.pack.add({
	"https://github.com/nvim-lua/plenary.nvim",
	"https://github.com/nvim-telescope/telescope.nvim",
	"https://github.com/nvim-telescope/telescope-fzf-native.nvim",
	"https://github.com/nvim-telescope/telescope-ui-select.nvim",
	"https://github.com/nvim-tree/nvim-web-devicons",
})

local telescope = require("telescope")
local actions = require("telescope.actions")

--- Telescope indents the selected row with selection_caret and every other row
--- with entry_prefix, so the row under the cursor slides sideways unless the two
--- are the same width. Derived rather than written out, to stay that way.
local selection_caret = vim.g.have_nerd_font and " " or "-> "
local entry_prefix = (" "):rep(vim.fn.strdisplaywidth(selection_caret))

telescope.setup({
	defaults = {
		path_display = { "truncate" },
		mappings = {
			i = { ["<C-j>"] = actions.move_selection_next, ["<C-k>"] = actions.move_selection_previous },
		},
		layout_strategy = "horizontal",
		layout_config = { horizontal = { preview_width = 0.55 } },
		borderchars = { "─", "│", "─", "│", "╭", "╮", "╯", "╰" },
		prompt_prefix = vim.g.have_nerd_font and "  " or "> ",
		selection_caret = selection_caret,
		entry_prefix = entry_prefix,
	},
	extensions = {
		["fzf"] = { override_generic_sorter = true, override_file_sorter = true, case_mode = "smart_case" },
		["ui-select"] = { require("telescope.themes").get_dropdown({}) },
	},
})

-- fzf-native is a compiled sorter. Without its library telescope still works on the
-- built-in one, so this must not raise: failing here would abort the rest of init.lua.
if not pcall(telescope.load_extension, "fzf") then
	vim.notify(
		"telescope-fzf-native is not built (needs make and a C compiler); using the slower built-in sorter",
		vim.log.levels.WARN
	)
end
telescope.load_extension("ui-select")

local builtin = require("telescope.builtin")
local files = require("plugins.editor.telescope.files")
local grep = require("plugins.editor.telescope.grep")
local keymaps = require("plugins.editor.telescope.keymaps")
local map = vim.keymap.set

map("n", "<leader>sw", builtin.grep_string, { desc = "Search for word under cursor in all files" })
map("n", "<leader>sb", builtin.buffers, { desc = "Search open buffers and switch" })
map("n", "<leader>sr", builtin.resume, { desc = "Search resume last search" })
map("n", "<leader>sh", builtin.help_tags, { desc = "Search help documentation" })
map("n", "<leader>sd", builtin.diagnostics, { desc = "Search diagnostics errors and warnings" })
map("n", "<leader>sm", builtin.marks, { desc = "Search marks and jump to them" })
map("n", "<leader>so", builtin.oldfiles, { desc = "Search recently opened files" })
map("n", "<leader>s/", builtin.search_history, { desc = "Search previous search queries" })

map("n", "<leader>sk", keymaps.pick, { desc = "Search keymaps by domain" })
map("n", "<leader>sK", function()
	keymaps.pick({ show_unlabelled = true })
end, { desc = "Search keymaps including unlabelled and plugin internals" })

map("n", "<leader>sn", function()
	builtin.find_files({ cwd = vim.fn.stdpath("config") })
end, { desc = "Search neovim config files" })

map("n", "<leader><leader>", function()
	builtin.current_buffer_fuzzy_find(require("telescope.themes").get_dropdown({
		winblend = 10,
		previewer = false,
	}))
end, { desc = "Search fuzzy text in current buffer" })

map("n", "<leader>sf", files.find_files_with_glob_filter, { desc = "Search find files by name (query  *.glob)" })
map("n", "<leader>sg", grep.grep_with_glob_filter, { desc = "Search grep text (pattern  *.glob)" })
map("n", "<leader>s.", grep.grep_current_file_directory, { desc = "Search grep in current file directory" })

map("n", "<leader>gc", grep.grep_changed_files, { desc = "Git grep only in changed files" })
map("n", "<leader>gl", builtin.git_commits, { desc = "Git log commits with diff preview" })
