--- Treesitter syntax highlighting and text objects.
--- Uses nvim-treesitter main branch targeting nvim 0.12+. Highlighting uses
--- vim.treesitter.start() per FileType. Incremental selection is built in:
--- `an` grows and `in` shrinks the selection in visual mode.

vim.pack.add({
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		version = "main",
	},
	"https://github.com/nvim-treesitter/nvim-treesitter-textobjects",
})

require("nvim-treesitter").setup({
	install_dir = vim.fn.stdpath("data") .. "/site",
})

local parsers = {
	"lua",
	"vim",
	"vimdoc",
	"c",
	"cpp",
	"rust",
	"python",
	"markdown",
	"markdown_inline",
	"bash",
	"fish",
	"nix",
	"toml",
	"cmake",
	"make",
	"json",
	"yaml",
}

-- Install parsers asynchronously on startup; no-op if already installed.
require("nvim-treesitter").install(parsers)

vim.api.nvim_create_autocmd("FileType", {
	desc = "Start treesitter highlighting for filetypes with an installed parser",
	group = vim.api.nvim_create_augroup("treesitter-highlight", { clear = true }),
	callback = function(ev)
		local lang = vim.treesitter.language.get_lang(ev.match)
		if lang and vim.list_contains(parsers, lang) then
			vim.treesitter.start(ev.buf, lang)
		end
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

local move_maps = {
	{ "]f", "@function.outer", "goto_next_start", "Jump to next function" },
	{ "]a", "@parameter.outer", "goto_next_start", "Jump to next argument" },
	{ "]c", "@class.outer", "goto_next_start", "Jump to next class" },
	{ "[f", "@function.outer", "goto_previous_start", "Jump to previous function" },
	{ "[a", "@parameter.outer", "goto_previous_start", "Jump to previous argument" },
	{ "[c", "@class.outer", "goto_previous_start", "Jump to previous class" },
}

--- ]c and [c jump between changes in diff mode, so leave them native there.
---@param lhs string
local function is_native_diff_motion(lhs)
	return vim.wo.diff and (lhs == "]c" or lhs == "[c")
end

for _, m in ipairs(move_maps) do
	vim.keymap.set({ "n", "x", "o" }, m[1], function()
		if is_native_diff_motion(m[1]) then
			vim.cmd.normal({ vim.v.count1 .. m[1], bang = true })
			return
		end
		move[m[3]](m[2], "textobjects")
	end, { desc = m[4] })
end
