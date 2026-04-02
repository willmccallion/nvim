--- @module plugins.lsp.servers.pyright
--- @brief Pyright LSP config for Python.
--- Auto search paths, library type stubs, and workspace-level diagnostics.

return {
	cmd = { "pyright-langserver", "--stdio" },
	filetypes = { "python" },
	root_markers = {
		"pyproject.toml",
		"setup.py",
		"setup.cfg",
		"requirements.txt",
		".git",
	},
	settings = {
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "workspace",
			},
		},
	},
}
