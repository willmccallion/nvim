--- @file gitsigns.lua
--- @brief Configuration for gitsigns.nvim, providing git decorations and hunk management.
--- @details This module sets up gitsigns with custom signs and keymaps for hunk navigation, staging, and blaming.

vim.pack.add({ "https://github.com/lewis6991/gitsigns.nvim" })

require("gitsigns").setup({
	signs = {
		add = { text = "│" },
		change = { text = "│" },
		delete = { text = "_" },
		topdelete = { text = "‾" },
		changedelete = { text = "~" },
	},

	--- @brief Callback function triggered when gitsigns attaches to a buffer.
	--- @param bufnr number The buffer number where gitsigns is attached.
	--- @details Sets up buffer-local keymaps for git operations like hunk navigation, staging, and blaming.
	--- @return nil
	on_attach = function(bufnr)
		local gs = package.loaded.gitsigns
		--- @brief Helper function to create buffer-local key mappings.
		--- @param mode string|table The mode(s) for the mapping (e.g., 'n', 'v').
		--- @param l string The left-hand side of the mapping (the keys).
		--- @param r string|function The right-hand side of the mapping (the action).
		--- @param opts table|nil Optional mapping settings (e.g., desc).
		--- @return nil
		local map = function(mode, l, r, opts)
			opts = opts or {}
			opts.buffer = bufnr
			vim.keymap.set(mode, l, r, opts)
		end

		map("n", "]c", function()
			gs.next_hunk()
		end, { desc = "Next Hunk" })

		map("n", "[c", function()
			gs.prev_hunk()
		end, { desc = "Prev Hunk" })

		map("n", "<leader>hs", gs.stage_hunk, { desc = "[H]unk [S]tage" })
		map("n", "<leader>hr", gs.reset_hunk, { desc = "[H]unk [R]eset" })
		map("v", "<leader>hs", function()
			gs.stage_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "Stage Hunk" })
		map("v", "<leader>hr", function()
			gs.reset_hunk({ vim.fn.line("."), vim.fn.line("v") })
		end, { desc = "Reset Hunk" })
		map("n", "<leader>hu", gs.undo_stage_hunk, { desc = "[H]unk [U]ndo Stage" })
		map("n", "<leader>hp", gs.preview_hunk, { desc = "[H]unk [P]review" })
		map("n", "<leader>hb", function()
			gs.blame_line({ full = true })
		end, { desc = "[H]unk [B]lame Line" })
	end,
})
