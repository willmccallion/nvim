--- @module plugins.lsp.servers.rust_analyzer
--- @brief Rust-analyzer LSP config.
--- Enables Clippy check-on-save and all Cargo features.

return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_markers = { "Cargo.toml", "rust-project.json", ".git" },
	settings = {
		["rust-analyzer"] = {
			checkOnSave = true,
			check = { command = "clippy" },
			cargo = { allFeatures = true },
		},
	},
}
