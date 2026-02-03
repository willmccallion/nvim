--- @module lsp.servers.lua_ls
--- @brief Configuration for the Lua Language Server (lua_ls).
--- @description This module defines the settings for the Lua LSP, including runtime environment,
--- diagnostics for Neovim globals, and workspace library paths optimized for Neovim development.

return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".luarc.json", ".luacheckrc", ".git" },
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
