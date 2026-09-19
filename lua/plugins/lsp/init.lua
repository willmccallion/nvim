--- LSP client lifecycle and keybindings.
--- Enables the server configs in the top-level lsp/ directory via vim.lsp.enable
--- and sets up LSP keybindings (go-to-definition, references, rename, etc.) on attach.

vim.lsp.config("*", {
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

vim.lsp.enable({ "clangd", "lua_ls", "rust_analyzer", "pyright", "nixd" })

-- Built-in gr* maps would make the gr mapping wait for 'timeoutlen'.
local builtin_gr_maps = { n = { "grr", "grn", "gri", "grt", "grx", "gra" }, x = { "gra" } }
for mode, lhss in pairs(builtin_gr_maps) do
	for _, lhs in ipairs(lhss) do
		if vim.fn.maparg(lhs, mode) ~= "" then
			vim.keymap.del(mode, lhs)
		end
	end
end

vim.api.nvim_create_autocmd("LspAttach", {
	desc = "Set LSP keymaps in the attached buffer",
	group = vim.api.nvim_create_augroup("lsp-attach", { clear = true }),
	callback = function(ev)
		---@param modes? string|string[] defaults to normal mode
		local map = function(keys, func, desc, modes)
			vim.keymap.set(modes or "n", keys, func, { buffer = ev.buf, desc = desc })
		end

		local builtin = require("telescope.builtin")

		map("gd", builtin.lsp_definitions, "LSP go to definition")
		map("gD", vim.lsp.buf.declaration, "LSP go to declaration (header file)")
		map("<leader>ci", builtin.lsp_implementations, "Code go to implementation")
		map("<leader>ct", builtin.lsp_type_definitions, "Code go to type definition")
		map("gr", builtin.lsp_references, "LSP find references to symbol")
		map("K", vim.lsp.buf.hover, "LSP show hover documentation")
		map("gK", vim.lsp.buf.signature_help, "LSP show function signature and parameters")
		map("<leader>ss", builtin.lsp_document_symbols, "Search symbols in current file")
		map("<leader>sS", builtin.lsp_dynamic_workspace_symbols, "Search symbols across entire project")
		map("<leader>cr", vim.lsp.buf.rename, "Code rename symbol across all files")
		map("<leader>ca", vim.lsp.buf.code_action, "Code action (quick fix, refactor)", { "n", "x" })

		map("<leader>oi", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
		end, "Option toggle inlay hints (inline type annotations)")
	end,
})

vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", { desc = "Show LSP configs and attached clients" })
