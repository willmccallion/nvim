--- @module plugins.editor.telescope
--- @brief Fuzzy finder via Telescope with fzf-native and ui-select extensions.
--- Find files, live grep, buffers, diagnostics, help, keymaps, and more
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
map("n", "<leader>sg", builtin.live_grep, { desc = "Search grep text in all files" })
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
