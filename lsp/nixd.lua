--- nixd LSP config for Nix.
--- Formatting is handled by conform (nixfmt), not the server.

---@type vim.lsp.Config
return {
	cmd = { "nixd" },
	filetypes = { "nix" },
	root_markers = { "flake.nix", ".git" },
}
