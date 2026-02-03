--- @module lsp.clangd
--- @brief Configuration for the clangd Language Server Protocol (LSP).
--- This module defines the command and arguments used to initialize clangd for C/C++ development.

return {
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
	},
}
