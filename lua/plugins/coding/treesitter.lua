--- @module plugins.coding.treesitter
--- @brief Treesitter syntax highlighting, text objects, and incremental selection.
--- Parsers auto-install on use. Includes treesitter-textobjects for selecting
--- and jumping between functions, classes, arguments, conditionals, and loops.

vim.pack.add({
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		version = "master",
	},
})
vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" })

require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"lua",
		"vim",
		"vimdoc",
		"c",
		"cpp",
		"rust",
		"python",
		"javascript",
		"typescript",
		"markdown",
		"markdown_inline",
		"bash",
	},
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	},
	indent = {
		enable = true,
	},
	incremental_selection = {
		enable = true,
		keymaps = {
			init_selection = "<leader>v",
			node_incremental = "<leader>v",
			node_decremental = "<leader>V",
			scope_incremental = false,
		},
	},
})

local tsto = require("nvim-treesitter-textobjects")
local move = require("nvim-treesitter-textobjects.move")
local select = require("nvim-treesitter-textobjects.select")

tsto.setup({
	select = {
		lookahead = true,
	},
	move = {
		set_jumps = true,
	},
})

-- Text object selections (work with d, c, y, v)
local sel_maps = {
	{ "af", "@function.outer", "Select around function" },
	{ "if", "@function.inner", "Select inside function body" },
	{ "ac", "@class.outer", "Select around class" },
	{ "ic", "@class.inner", "Select inside class body" },
	{ "aa", "@parameter.outer", "Select around argument" },
	{ "ia", "@parameter.inner", "Select inside argument" },
	{ "ai", "@conditional.outer", "Select around if/conditional" },
	{ "ii", "@conditional.inner", "Select inside if/conditional" },
	{ "al", "@loop.outer", "Select around loop" },
	{ "il", "@loop.inner", "Select inside loop" },
}

for _, m in ipairs(sel_maps) do
	vim.keymap.set({ "x", "o" }, m[1], function()
		select.select_textobject(m[2], "textobjects")
	end, { desc = m[3] })
end

-- Move to next/previous function, argument, class
local move_maps = {
	{ "]f", "@function.outer", "goto_next_start", "Jump to next function" },
	{ "]a", "@parameter.outer", "goto_next_start", "Jump to next argument" },
	{ "]C", "@class.outer", "goto_next_start", "Jump to next class" },
	{ "[f", "@function.outer", "goto_previous_start", "Jump to previous function" },
	{ "[a", "@parameter.outer", "goto_previous_start", "Jump to previous argument" },
	{ "[C", "@class.outer", "goto_previous_start", "Jump to previous class" },
}

for _, m in ipairs(move_maps) do
	vim.keymap.set({ "n", "x", "o" }, m[1], function()
		move[m[3]](m[2], "textobjects")
	end, { desc = m[4] })
end

vim.api.nvim_create_autocmd("PackChanged", {
	desc = "Handle nvim-treesitter updates",
	group = vim.api.nvim_create_augroup("nvim-treesitter-pack-changed-update-handler", { clear = true }),
	callback = function(event)
		if event.data.kind == "update" and event.data.spec.name == "nvim-treesitter" then
			vim.notify("nvim-treesitter updated, running TSUpdate...", vim.log.levels.INFO)
			local ok = pcall(vim.cmd, "TSUpdate")
			if ok then
				vim.notify("TSUpdate completed successfully!", vim.log.levels.INFO)
			else
				vim.notify("TSUpdate command not available yet, skipping", vim.log.levels.WARN)
			end
		end
	end,
})
