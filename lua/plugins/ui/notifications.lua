--- Every vim.notify message and LSP progress, via fidget.nvim.
--- Shows notifications, build status and LSP activity in the bottom right, in
--- normal text colour. Routing vim.notify here keeps messages out of the command
--- line, where long ones would stop for a "Press ENTER" prompt. Loaded before the
--- other plugins so their own startup messages arrive here too.
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
