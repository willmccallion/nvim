--- @module lsp.servers.rust_analyzer
--- @brief LSP configuration for the rust-analyzer language server.
--- @description Provides the command, filetypes, root markers, and specific settings
--- for Rust development, including Clippy integration and Cargo feature support.

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
