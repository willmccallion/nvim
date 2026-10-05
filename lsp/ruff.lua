--- Ruff LSP config for Python linting, alongside pyright for types.
--- Formatting goes through conform (ruff_format), not the server.

---@type vim.lsp.Config
return {
	cmd = { "ruff", "server" },
	filetypes = { "python" },
	root_markers = { "pyproject.toml", "ruff.toml", ".ruff.toml", ".git" },
	--- Ruff's hover only explains noqa codes, and would compete with pyright's for K.
	on_attach = function(client)
		client.server_capabilities.hoverProvider = false
	end,
}
