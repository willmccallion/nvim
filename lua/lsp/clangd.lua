--- @file clangd.lua
--- @brief Configuration for the clangd Language Server Protocol (LSP).
--- @details This module defines the command-line arguments and settings required to
--- initialize the clangd language server within a Neovim environment.

--- @brief Entry point for the clangd LSP configuration.
--- @return table The configuration object for clangd.
return {
	cmd = {
		"clangd",
		"--background-index",
		"--clang-tidy",
	},
}
