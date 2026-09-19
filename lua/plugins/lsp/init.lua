--- @module plugins.lsp
--- @brief LSP client lifecycle and keybindings.
--- Enables the server configs in the top-level lsp/ directory via vim.lsp.enable
--- and sets up LSP keybindings (go-to-definition, references, rename, etc.) on attach.

vim.lsp.config("*", {
	capabilities = require("cmp_nvim_lsp").default_capabilities(),
})

vim.lsp.enable({ "clangd", "lua_ls", "rust_analyzer", "pyright" })

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
		end

		local builtin = require("telescope.builtin")

		map("gd", builtin.lsp_definitions, "Go to definition of symbol")
		map("gD", vim.lsp.buf.declaration, "Go to declaration (header file)")
		map("gi", builtin.lsp_implementations, "Go to implementation of interface")
		map("gt", builtin.lsp_type_definitions, "Go to type definition of variable")
		map("gr", builtin.lsp_references, "Find all references to symbol")
		map("K", vim.lsp.buf.hover, "Show hover documentation for symbol")
		map("gK", vim.lsp.buf.signature_help, "Show function signature and parameters")
		map("<leader>ds", builtin.lsp_document_symbols, "List all symbols in current file")
		map("<leader>ws", builtin.lsp_dynamic_workspace_symbols, "Search symbols across entire project")
		map("<leader>rn", vim.lsp.buf.rename, "Rename symbol across all files")
		map("<leader>ca", vim.lsp.buf.code_action, "Code action quick fix refactor")

		map("<leader>ih", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
		end, "Toggle inlay hints (inline type annotations)")
	end,
})

vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", { desc = "Show LSP configs and attached clients" })
