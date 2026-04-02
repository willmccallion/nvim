--- @module plugins.gitsigns
--- @brief Git integration for the Neovim sign column.
--- @description Configures gitsigns.nvim to provide visual indicators for git changes
--- and provides keybindings for hunk navigation, staging, and previewing.

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
			gs.next_hunk()
		end, { desc = "Git go to next changed hunk" })

		map("n", "[c", function()
			gs.prev_hunk()
		end, { desc = "Git go to previous changed hunk" })

		map("n", "<leader>hs", gs.stage_hunk, { desc = "Git stage hunk" })
		map("n", "<leader>hr", gs.reset_hunk, { desc = "Git reset hunk (discard changes)" })
		map("v", "<leader>hs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "Git stage selected lines" })
		map("v", "<leader>hr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "Git reset selected lines" })
		map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "Git undo last stage hunk" })
		map("n", "<leader>hp", gs.preview_hunk, { desc = "Git preview hunk diff inline" })
		map("n", "<leader>hb", function()
			gs.blame_line({ full = true })
		end, { desc = "Git blame show who changed this line" })
	end,
})
