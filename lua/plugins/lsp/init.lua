--- LSP client lifecycle and keybindings.
--- Enables the server configs in the top-level lsp/ directory via vim.lsp.enable
--- and sets up LSP keybindings (go-to-definition, references, rename, etc.) on attach.
--- Renaming goes through inc-rename so 'inccommand' previews every affected site
--- as you type, instead of applying the edit unseen.

vim.pack.add({ "https://github.com/smjonas/inc-rename.nvim" })

require("inc_rename").setup()

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
		vim.keymap.set("n", "<leader>cr", function()
			return ":IncRename " .. vim.fn.expand("<cword>")
		end, { buffer = ev.buf, expr = true, desc = "Code rename symbol across all files" })

		map("<leader>ca", vim.lsp.buf.code_action, "Code action (quick fix, refactor)", { "n", "x" })
		map("<leader>cl", vim.lsp.codelens.run, "Code run the lens on this line")

		map("<leader>oi", function()
			vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
		end, "Option toggle inlay hints (inline type annotations)")

		map("<leader>oc", function()
			vim.lsp.codelens.enable(not vim.lsp.codelens.is_enabled({ bufnr = ev.buf }), { bufnr = ev.buf })
		end, "Option toggle code lenses (run, debug, implementation counts)")
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	desc = "Fold by the server's ranges rather than the syntax tree",
	group = vim.api.nvim_create_augroup("lsp-folding", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or not client:supports_method("textDocument/foldingRange") then
			return
		end
		-- 'foldexpr' is window-local, so every window on the buffer needs it, not
		-- just the one that happened to be current when the server attached.
		for _, win in ipairs(vim.fn.win_findbuf(ev.buf)) do
			vim.wo[win][0].foldexpr = "v:lua.vim.lsp.foldexpr()"
		end
	end,
})

vim.api.nvim_create_autocmd("LspAttach", {
	desc = "Highlight other references to the symbol under the cursor",
	group = vim.api.nvim_create_augroup("lsp-document-highlight", { clear = true }),
	callback = function(ev)
		local client = vim.lsp.get_client_by_id(ev.data.client_id)
		if not client or not client:supports_method("textDocument/documentHighlight") then
			return
		end

		-- A second client attaching to the same buffer would otherwise double these up.
		local group = vim.api.nvim_create_augroup("lsp-document-highlight-buffer", { clear = false })
		vim.api.nvim_clear_autocmds({ group = group, buffer = ev.buf })
		vim.api.nvim_create_autocmd({ "CursorHold", "CursorHoldI" }, {
			group = group,
			buffer = ev.buf,
			callback = vim.lsp.buf.document_highlight,
		})
		vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
			group = group,
			buffer = ev.buf,
			callback = vim.lsp.buf.clear_references,
		})
	end,
})

vim.api.nvim_create_user_command("LspInfo", "checkhealth vim.lsp", { desc = "Show LSP configs and attached clients" })
