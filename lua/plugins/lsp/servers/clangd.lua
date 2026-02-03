--- @module lsp.servers.clangd
--- @brief Configuration for the clangd Language Server Protocol (LSP) server.
--- @description This module defines the command-line arguments, supported filetypes, and
--- root directory markers used to initialize clangd for C, C++, and related languages.

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
