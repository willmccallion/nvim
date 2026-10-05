--- Pyright LSP config for Python.
--- Auto search paths, library type stubs, and workspace-level diagnostics.
--- Imports are ruff's to organize, so the code action is not offered twice.

---@type vim.lsp.Config
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
		pyright = { disableOrganizeImports = true },
		python = {
			analysis = {
				autoSearchPaths = true,
				useLibraryCodeForTypes = true,
				diagnosticMode = "workspace",
			},
		},
	},
}
