--- zls LSP config for Zig, including build.zig.zon manifests.
--- Formatting is handled by conform (zig fmt), not the server.

---@type vim.lsp.Config
return {
	cmd = { "zls" },
	filetypes = { "zig" },
	root_markers = { "zls.json", "build.zig", ".git" },
}
