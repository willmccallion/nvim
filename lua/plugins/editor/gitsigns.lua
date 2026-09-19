--- Git sign column indicators and hunk management.
--- Shows added/changed/deleted lines in the sign column. Keymaps for staging,
--- resetting, previewing, and blaming hunks under <leader>g.

vim.pack.add({ "https://github.com/lewis6991/gitsigns.nvim" })

require("gitsigns").setup({
	signs = {
		add = { text = "│" },
		change = { text = "│" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
	},

	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns
		local map = function(mode, l, r, opts)
			opts = opts or {}
			opts.buffer = bufnr
			vim.keymap.set(mode, l, r, opts)
		end

		map("n", "]c", function()
			gs.nav_hunk("next")
		end, { desc = "Git go to next changed hunk" })

		map("n", "[c", function()
			gs.nav_hunk("prev")
		end, { desc = "Git go to previous changed hunk" })

		map("n", "<leader>gs", gs.stage_hunk, { desc = "Git stage or unstage hunk" })
		map("n", "<leader>gr", gs.reset_hunk, { desc = "Git reset hunk (discard changes)" })
		map("v", "<leader>gs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "Git stage or unstage selected lines" })
		map("v", "<leader>gr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "Git reset selected lines" })
		map("n", "<leader>gp", gs.preview_hunk, { desc = "Git preview hunk diff inline" })
		map("n", "<leader>gb", function()
			gs.blame_line({ full = true })
		end, { desc = "Git blame show who changed this line" })
	end,
})
