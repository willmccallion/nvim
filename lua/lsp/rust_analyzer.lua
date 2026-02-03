--- @module lsp.rust_analyzer
--- @brief Configuration settings for the rust-analyzer Language Server Protocol (LSP).
--- @details This module provides a table of settings for rust-analyzer, specifically
--- configuring it to use clippy for on-save checks and enabling all cargo features.

return {
	settings = {
		["rust-analyzer"] = {
			checkOnSave = true,

			check = {
				command = "clippy",
			},

			cargo = {
				allFeatures = true,
			},
		},
	},
}
