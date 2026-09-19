--- @module plugins.ui.treesitter_context
--- @brief Sticky scope header via nvim-treesitter-context.
--- Pins the enclosing function/class/loop line to the top of the window while
--- scrolling through its body. [x jumps up to that context line.

vim.pack.add({ "https://github.com/nvim-treesitter/nvim-treesitter-context" })

require("treesitter-context").setup({
	max_lines = 3,
})

vim.keymap.set("n", "[x", function()
	require("treesitter-context").go_to_context(vim.v.count1)
end, { desc = "Jump to enclosing scope shown in sticky context header" })
