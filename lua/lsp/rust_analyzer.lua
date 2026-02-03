--- @file rust_analyzer.lua
--- @brief Configuration for the rust-analyzer Language Server Protocol (LSP).
--- This module defines the settings used by the LSP client to initialize
--- and configure the rust-analyzer server.

--- @brief Entry point for the rust-analyzer configuration module.
--- @return table The configuration settings for rust-analyzer.
return {
	settings = {
		["rust-analyzer"] = {
			checkOnSave = true,

			check = {
				command = "clippy",
			},

			cargo = {
				allFeatures = true,
			},
		},
	},
}
