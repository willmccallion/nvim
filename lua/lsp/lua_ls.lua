--- @file lua_ls.lua
--- @brief Configuration for the Lua Language Server (lua_ls).
---
--- This file defines the configuration settings for the Lua Language Server,
--- specifically tailored for Neovim development. It configures the runtime,
--- diagnostics, workspace libraries, and telemetry.

--- @brief Entry point for the lua_ls configuration module.
--- @return table The configuration table for the language server.
return {
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			diagnostics = { globals = { "vim" } },
			workspace = {
				library = vim.api.nvim_get_runtime_file("", true),
				checkThirdParty = false,
			},
			telemetry = { enable = false },
		},
	},
}
