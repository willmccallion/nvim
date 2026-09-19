--- Lua Language Server config for Neovim Lua development.
--- LuaJIT runtime with Neovim's runtime and libuv types. Only plugins whose
--- types the config uses are indexed, which keeps startup indexing fast.

--- Plugins whose type annotations this config refers to (e.g. dap.Configuration).
local typed_plugins = { "nvim-dap" }

local library = { vim.env.VIMRUNTIME, "${3rd}/luv/library" }
for _, name in ipairs(typed_plugins) do
	table.insert(library, vim.fs.joinpath(vim.fn.stdpath("data"), "site", "pack", "core", "opt", name))
end

---@type vim.lsp.Config
return {
	cmd = { "lua-language-server" },
	filetypes = { "lua" },
	root_markers = { ".luarc.json", ".luacheckrc", ".git" },
	settings = {
		Lua = {
			runtime = { version = "LuaJIT" },
			workspace = {
				library = library,
				checkThirdParty = false,
			},
			telemetry = { enable = false },
		},
	},
}
