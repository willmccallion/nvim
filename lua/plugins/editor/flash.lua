--- Label-based jump navigation via flash.nvim.
--- Press s to search and jump to any visible text with labeled targets.

vim.pack.add({ "https://github.com/folke/flash.nvim" })

require("flash").setup({})

vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash jump to any visible text with search labels" })

--- Labels every node enclosing the cursor at once, where Neovim's own an widens
--- the selection a node per press. Normal mode only: nvim-surround owns S in
--- visual mode, and its yS and cS would shadow an operator-pending one.
vim.keymap.set("n", "S", function()
	require("flash").treesitter()
end, { desc = "Flash select enclosing syntax node by label" })
