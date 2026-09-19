--- LSP progress notifications via fidget.nvim.
--- Shows LSP activity and build status in the bottom right, in normal text colour.

vim.pack.add({ "https://github.com/j-hui/fidget.nvim" })

require("fidget").setup({
	notification = {
		window = { normal_hl = "Normal" },
	},
})
