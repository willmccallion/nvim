--- @module plugins.editor.flash
--- @brief Label-based jump navigation via flash.nvim.
--- Press s to search and jump to any visible text with labeled targets.

vim.pack.add({ "https://github.com/folke/flash.nvim" })

require("flash").setup({})

vim.keymap.set({ "n", "x", "o" }, "s", function()
	require("flash").jump()
end, { desc = "Flash jump to any visible text with search labels" })
