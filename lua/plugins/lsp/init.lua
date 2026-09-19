--- LSP client lifecycle and keybindings.
--- Enables the server configs in the top-level lsp/ directory via vim.lsp.enable
--- and sets up LSP keybindings (go-to-definition, references, rename, etc.) on attach.

vim.lsp.config("*", {
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

vim.lsp.enable({ "clangd", "lua_ls", "rust_analyzer", "pyright", "nixd" })

-- Built-in gr* maps would make the gr mapping wait for 'timeoutlen'.
for _, lhs in ipairs({ "grr", "grn", "gri", "grt", "grx" }) do
	vim.keymap.del("n", lhs)
end
vim.keymap.del({ "n", "x" }, "gra")

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
		end

		local builtin = require("telescope.builtin")

		map("gd", builtin.lsp_definitions, "LSP go to definition")
		map("gD", vim.lsp.buf.declaration, "LSP go to declaration (header file)")
		map("gi", builtin.lsp_implementations, "LSP go to implementation")
		map("gt", builtin.lsp_type_definitions, "LSP go to type definition")
		map("gr", builtin.lsp_references, "LSP find references to symbol")
		map("K", vim.lsp.buf.hover, "LSP show hover documentation")
		map("gK", vim.lsp.buf.signature_help, "LSP show function signature and parameters")
		map("<leader>ss", builtin.lsp_document_symbols, "Search symbols in current file")
		map("<leader>sS", builtin.lsp_dynamic_workspace_symbols, "Search symbols across entire project")
		map("<leader>rn", vim.lsp.buf.rename, "LSP rename symbol across all files")
		map("<leader>ca", vim.lsp.buf.code_action, "LSP code action (quick fix, refactor)")

		map("<leader>ih", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
		end, "LSP toggle inlay hints (inline type annotations)")
	end,
})

vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", { desc = "Show LSP configs and attached clients" })
