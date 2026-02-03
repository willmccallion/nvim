--- @module lsp.lua_ls
--- @brief Configuration settings for the Lua Language Server (lua_ls).
--- @description Provides a standard configuration for lua_ls, including Neovim runtime
--- libraries, LuaJIT compatibility, and diagnostic global definitions.

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
