--- @module plugins.coding.treesitter
--- @brief Treesitter syntax highlighting and text objects.
--- Uses nvim-treesitter main branch targeting nvim 0.12+. Highlighting uses
--- vim.treesitter.start() per FileType. Incremental selection is built in:
--- `an` grows and `in` shrinks the selection in visual mode.

vim.pack.add({
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		version = "main",
	},
})
vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter-textobjects" })

require("nvim-treesitter").setup({
	install_dir = vim.fn.stdpath("data") .. "/site",
})

-- Install parsers asynchronously on startup; no-op if already installed.
require("nvim-treesitter").install({
	"lua",
	"vim",
	"vimdoc",
	"c",
	"zig",
	"rust",
	"python",
	"markdown",
	"markdown_inline",
	"bash",
	"fish",
})

-- Highlighting is driven by Neovim's built-in vim.treesitter.start().
-- FileType names differ from parser names for a few languages:
--   vimdoc parser → "help" filetype
--   bash parser   → "sh" filetype
vim.api.nvim_create_autocmd("FileType", {
	group = vim.api.nvim_create_augroup("treesitter-highlight", { clear = true }),
	pattern = {
		"lua",
		"vim",
		"help",
		"c",
		"zig",
		"rust",
		"python",
		"markdown",
		"sh",
		"fish",
	},
	callback = function()
		vim.treesitter.start()
	end,
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
