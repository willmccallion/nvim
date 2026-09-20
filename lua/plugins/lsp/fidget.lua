--- LSP progress and every vim.notify message, via fidget.nvim.
--- Shows LSP activity, build status and notifications in the bottom right, in
--- normal text colour. Routing vim.notify here keeps messages out of the command
--- line, where long ones would stop for a "Press ENTER" prompt.
--- `:Fidget history` lists messages that have already faded.

vim.pack.add({ "https://github.com/j-hui/fidget.nvim" })

require("fidget").setup({
	notification = {
		override_vim_notify = true,
		-- Five seconds is tight for an error you have to act on.
		configs = {
			default = vim.tbl_extend("force", require("fidget.notification").default_config, { ttl = 8 }),
		},
		window = { normal_hl = "Normal" },
	},
})
