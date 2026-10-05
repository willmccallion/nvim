--- Makes bracket motions repeatable with ";" and ",".
--- nvim-treesitter-textobjects records the last of its moves for those two keys
--- (mapped in treesitter.lua); a pair wrapped here is recorded the same way, so
--- the repeat carries on with whichever bracket motion ran last. Neovim's own
--- diagnostic, quickfix, location list and buffer pairs are wrapped on load.

local repeatable = require("nvim-treesitter-textobjects.repeatable_move")

local M = {}

--- Each wrapped function reads v:count1 when it runs, so "3;" repeats three times.
---@param next_fn fun()
---@param prev_fn fun()
---@return fun() next
---@return fun() prev
function M.pair(next_fn, prev_fn)
	local move = repeatable.make_repeatable_move(function(opts)
		if opts.forward then
			next_fn()
		else
			prev_fn()
		end
	end)
	return function()
		move({ forward = true })
	end, function()
		move({ forward = false })
	end
end

local BUILTIN_PAIRS = {
	{ "]d", "[d" },
	{ "]q", "[q" },
	{ "]l", "[l" },
	{ "]b", "[b" },
}

---@param lhs string
---@return fun(), string
local function builtin_motion(lhs)
	local map = vim.fn.maparg(lhs, "n", false, true)
	return map.callback, map.desc
end

for _, keys in ipairs(BUILTIN_PAIRS) do
	local next_fn, next_desc = builtin_motion(keys[1])
	local prev_fn, prev_desc = builtin_motion(keys[2])
	if next_fn and prev_fn then
		local repeatable_next, repeatable_prev = M.pair(next_fn, prev_fn)
		vim.keymap.set("n", keys[1], repeatable_next, { desc = next_desc })
		vim.keymap.set("n", keys[2], repeatable_prev, { desc = prev_desc })
	else
		vim.notify(
			("%s/%s are no longer Lua defaults; ; and , will not repeat them"):format(keys[1], keys[2]),
			vim.log.levels.WARN
		)
	end
end

return M
