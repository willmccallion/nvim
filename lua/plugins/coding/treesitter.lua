--- Treesitter syntax highlighting, indentation and text objects.
--- Uses the nvim-treesitter main branch. Highlighting uses
--- vim.treesitter.start() per FileType, and indentation the plugin's
--- indentexpr. Incremental selection is built in: `an` grows and `in` shrinks
--- the selection in visual mode.

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
	"latex",
	"comment",
	"bash",
	"fish",
	"nix",
	"toml",
	"cmake",
	"make",
	"json",
	"yaml",
	"systemverilog",
	"zig",
}

-- Install parsers asynchronously on startup; no-op if already installed.
require("nvim-treesitter").install(parsers)

vim.api.nvim_create_autocmd("FileType", {
	desc = "Start treesitter highlighting and indentation for filetypes with an installed parser",
	group = vim.api.nvim_create_augroup("treesitter-highlight", { clear = true }),
	callback = function(ev)
		local lang = vim.treesitter.language.get_lang(ev.match)
		-- install() is asynchronous and needs a C compiler, so a wanted parser is not
		-- necessarily a present one. add() reports that rather than raising in start().
		if not (lang and vim.list_contains(parsers, lang) and vim.treesitter.language.add(lang)) then
			return
		end
		vim.treesitter.start(ev.buf, lang)
		-- Without an indents query every line would indent to 0, so those filetypes
		-- (vim, make) keep their own indent scripts.
		if vim.treesitter.query.get(lang, "indents") then
			vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
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

--- Classes sit on ]] and [[ rather than a letter: ]c and [c are Vim's own
--- diff-change motions, and gitsigns documents them for hunks.
local move_maps = {
	{ "]a", "@parameter.outer", "goto_next_start", "Jump to next argument" },
	{ "]]", "@class.outer", "goto_next_start", "Jump to next class" },
	{ "[a", "@parameter.outer", "goto_previous_start", "Jump to previous argument" },
	{ "[[", "@class.outer", "goto_previous_start", "Jump to previous class" },
}

for _, m in ipairs(move_maps) do
	vim.keymap.set({ "n", "x", "o" }, m[1], function()
		move[m[3]](m[2], "textobjects")
	end, { desc = m[4] })
end

local shared = require("nvim-treesitter-textobjects.shared")

--- The next or previous function start in the current window whose line isn't inside
--- a closed fold, found as the plugin's own moves find one; nil when there is none.
---@param forward boolean
---@return Range6?
local function visible_function_start(forward)
	local row, col = unpack(vim.api.nvim_win_get_cursor(0))
	row = row - 1
	local range = shared.find_best_range(0, "@function.outer", "textobjects", function(candidate)
		local start_row, start_col = candidate[1], candidate[2]
		if vim.fn.foldclosed(start_row + 1) ~= -1 then
			return false
		end
		if forward then
			return start_row > row or (start_row == row and start_col > col)
		end
		return start_row < row or (start_row == row and start_col < col)
	end, function(candidate)
		-- The nearest one wins; candidate[3] is its start's byte offset.
		return forward and -candidate[3] or candidate[3]
	end)
	-- With no parser for the buffer it returns an empty table, not nil.
	return range and range[1] and range or nil
end

--- ]f and [f step over functions hidden in closed folds, as j and k step over the fold,
--- so in g diff's collapsed previews they visit only the functions on show. Like the
--- plugin's moves, they leave a jump, take a count and work on an operator.
---@param forward boolean
local function goto_visible_function(forward)
	for _ = 1, vim.v.count1 do
		local range = visible_function_start(forward)
		if not range then
			return
		end
		vim.cmd("normal! m'")
		if vim.api.nvim_get_mode().mode == "no" then
			vim.cmd("normal! v")
		end
		vim.api.nvim_win_set_cursor(0, { range[1] + 1, range[2] })
	end
end

local next_function, previous_function = require("plugins.editor.motion_repeat").pair(function()
	goto_visible_function(true)
end, function()
	goto_visible_function(false)
end)
vim.keymap.set({ "n", "x", "o" }, "]f", next_function, { desc = "Jump to next function not in a closed fold" })
vim.keymap.set({ "n", "x", "o" }, "[f", previous_function, { desc = "Jump to previous function not in a closed fold" })

local swap = require("nvim-treesitter-textobjects.swap")

--- A shifted bracket moves the thing rather than moving to it, as <leader>wH moves
--- a window where <leader>wh moves to one. Separators come along with the node, so
--- a swapped argument does not leave its commas behind.
local swap_maps = {
	{ "]A", swap.swap_next, "@parameter.inner", "Swap argument with the next one" },
	{ "[A", swap.swap_previous, "@parameter.inner", "Swap argument with the previous one" },
	{ "]F", swap.swap_next, "@function.outer", "Swap function with the next one" },
	{ "[F", swap.swap_previous, "@function.outer", "Swap function with the previous one" },
}

for _, m in ipairs(swap_maps) do
	vim.keymap.set("n", m[1], function()
		m[2](m[3], "textobjects")
	end, { desc = m[4] })
end

local repeatable = require("nvim-treesitter-textobjects.repeatable_move")

--- The motions above, and the pairs motion_repeat.lua wraps, record themselves
--- as they run, so these carry on with whichever was used last. As with Vim's
--- f/t, ";" keeps the direction of that move and "," goes the other way.
---
--- f/F/t/T stay flash's, for the multi-line search it adds; its builtin_*_expr
--- wrappers would replace that with plain single-line f. Flash leaves these two
--- alone in turn: it skips a key that is the local leader, and skips ";" when
--- something already holds it, which loading before flash.lua is what ensures.
vim.keymap.set({ "n", "x", "o" }, ";", repeatable.repeat_last_move, { desc = "Motion repeat in the same direction" })
vim.keymap.set(
	{ "n", "x", "o" },
	",",
	repeatable.repeat_last_move_opposite,
	{ desc = "Motion repeat in the opposite direction" }
)
