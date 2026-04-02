--- @module plugins.lsp.servers.clangd
--- @brief Clangd LSP config for C/C++.
--- Enables background indexing and clang-tidy.

return {
	cmd = { "clangd", "--background-index", "--clang-tidy" },
	filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
	root_markers = {
		".clangd",
		".clang-tidy",
		".clang-format",
		"compile_commands.json",
		"compile_flags.txt",
		".git",
	},
}
