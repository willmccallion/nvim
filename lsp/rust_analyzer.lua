--- @module lsp.rust_analyzer
--- @brief Rust-analyzer LSP config.
--- Enables Clippy check-on-save and all Cargo features.

---@type vim.lsp.Config
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
