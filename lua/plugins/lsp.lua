--- @module plugins.lsp
--- @brief LSP configuration and initialization logic.
--- @description This module manages the setup of Language Server Protocol (LSP) clients.
--- It defines default settings for common servers (rust_analyzer, clangd, lua_ls),
--- implements custom root directory detection, merges user-specific configurations
--- from the `lsp.*` namespace, and establishes standard keybindings upon LSP attachment.

local capabilities = vim.lsp.protocol.make_client_capabilities()
local has_cmp, cmp_nvim_lsp = pcall(require, "cmp_nvim_lsp")
if has_cmp then
	capabilities = cmp_nvim_lsp.default_capabilities()
end

local builtin_defaults = {
	rust_analyzer = {
		cmd = { "rust-analyzer" },
		filetypes = { "rust" },
		root_markers = { "Cargo.toml", "rust-project.json", ".git" },
	},
	clangd = {
		cmd = { "clangd" },
		filetypes = { "c", "cpp", "objc", "objcpp", "cuda", "proto" },
		root_markers = {
			".clangd",
			".clang-tidy",
			".clang-format",
			"compile_commands.json",
			"compile_flags.txt",
			".git",
		},
	},
	lua_ls = {
		cmd = { "lua-language-server" },
		filetypes = { "lua" },
		root_markers = { ".luarc.json", ".luacheckrc", ".git" },
	},
}

local servers = { "rust_analyzer", "clangd", "lua_ls" }

local function get_root_finder(markers)
	return function(fname)
		local root = vim.fs.root(fname, markers)
		if root then
			return root
		end
		if fname and fname ~= "" then
			return vim.fs.dirname(fname)
		end
		return vim.fn.getcwd()
	end
end

for _, server in ipairs(servers) do
	local config = builtin_defaults[server] or {}

	local require_ok, user_settings = pcall(require, "lsp." .. server)
	if not require_ok then
		user_settings = {}
	end

	local final_config = vim.tbl_deep_extend("force", config, user_settings)
	final_config.capabilities = vim.tbl_deep_extend("force", capabilities, final_config.capabilities or {})

	local root_finder = nil
	if final_config.root_markers then
		root_finder = get_root_finder(final_config.root_markers)
	end

	local cmd_bin = final_config.cmd and final_config.cmd[1]
	if cmd_bin and vim.fn.executable(cmd_bin) == 1 then
		vim.api.nvim_create_autocmd("FileType", {
			pattern = final_config.filetypes,
			callback = function(ev)
				local root_dir = nil
				if root_finder then
					root_dir = root_finder(vim.api.nvim_buf_get_name(ev.buf))
				end
				local client_config = vim.tbl_deep_extend("force", final_config, { root_dir = root_dir })
				vim.lsp.start(client_config, { bufnr = ev.buf })
			end,
		})
	else
		vim.notify("LSP: Binary '" .. (cmd_bin or "unknown") .. "' not found for " .. server, vim.log.levels.WARN)
	end
end

vim.api.nvim_create_autocmd("LspAttach", {
	group = vim.api.nvim_create_augroup("UserLspConfig", {}),
	callback = function(ev)
		vim.bo[ev.buf].omnifunc = "v:lua.vim.lsp.omnifunc"
		local map = function(keys, func, desc)
			vim.keymap.set("n", keys, func, { buffer = ev.buf, desc = desc })
		end
		map("gd", vim.lsp.buf.definition, "[G]oto [D]efinition")
		map("K", vim.lsp.buf.hover, "Hover Documentation")
		map("gr", require("telescope.builtin").lsp_references, "[G]oto [R]eferences")
		map("<leader>rn", vim.lsp.buf.rename, "[R]e[n]ame")
		map("<leader>ca", vim.lsp.buf.code_action, "[C]ode [A]ction")
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
