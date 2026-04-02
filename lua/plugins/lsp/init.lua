--- @module plugins.lsp
--- @brief Core LSP initialization and configuration module.
--- This module manages the lifecycle of Language Server Protocol (LSP) clients.
--- It dynamically loads server-specific configurations, handles automatic client
--- startup via FileType autocommands, and sets up global LSP keybindings and
--- diagnostic commands.

local capabilities = vim.lsp.protocol.make_client_capabilities()
local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if has_cmp then
	capabilities = cmp_nvim_lsp.default_capabilities()
end

local servers = { "clangd", "lua_ls", "rust_analyzer", "pyright" }

for _, server_name in ipairs(servers) do
	local ok, config = pcall(require, "plugins.lsp.servers." .. server_name)
	if not ok then
		vim.notify("Could not load LSP config for: " .. server_name, vim.log.levels.ERROR)
		goto continue
	end

	if not config.cmd or not config.filetypes then
		vim.notify("LSP config for " .. server_name .. " missing 'cmd' or 'filetypes'", vim.log.levels.ERROR)
		goto continue
	end

	vim.api.nvim_create_autocmd("FileType", {
		pattern = config.filetypes,
		group = vim.api.nvim_create_augroup("lsp-start-" .. server_name, { clear = true }),
		callback = function(ev)
			local root_dir = vim.fs.dirname(vim.api.nvim_buf_get_name(ev.buf))
			if config.root_markers then
				local found = vim.fs.find(config.root_markers, {
					upward = true,
					path = root_dir,
				})[1]
				if found then
					root_dir = vim.fs.dirname(found)
				end
			end

			if vim.fn.executable(config.cmd[1]) == 1 then
				vim.lsp.start({
					name = server_name,
					cmd = config.cmd,
					root_dir = root_dir,
					capabilities = capabilities,
					settings = config.settings or {},
				})
			end
		end,
	})

	::continue::
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
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

vim.api.nvim_create_user_command("LspInfo", function()
	local clients = vim.lsp.get_clients({ bufnr = 0 })
	if #clients == 0 then
		vim.notify("No active LSP clients in this buffer.", vim.log.levels.WARN)
		return
	end
	local info = { "LSP Clients attached to this buffer:" }
	for _, client in ipairs(clients) do
		table.insert(info, "--------------------")
		table.insert(info, "Client: " .. client.name .. " (id: " .. client.id .. ")")
		table.insert(info, "Root:   " .. (client.config.root_dir or "nil"))
		table.insert(info, "Cmd:    " .. table.concat(client.config.cmd or {}, " "))
	end
	vim.notify(table.concat(info, "\n"), vim.log.levels.INFO)
end, {})
