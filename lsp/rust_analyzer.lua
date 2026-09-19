--- Rust-analyzer LSP config.
--- Enables Clippy check-on-save and all Cargo features. Roots at the Cargo
--- workspace so every member crate shares one server.

--- Asks Cargo for the workspace root, falling back to the nearest crate or git root.
---@param bufnr integer
---@param on_dir fun(root_dir?: string)
local function cargo_workspace_root(bufnr, on_dir)
	local crate_root = vim.fs.root(bufnr, { "Cargo.toml", "rust-project.json" })
	if not crate_root or vim.fn.executable("cargo") == 0 then
		on_dir(crate_root or vim.fs.root(bufnr, ".git"))
		return
	end
	vim.system(
		{ "cargo", "locate-project", "--workspace", "--message-format", "plain" },
		{ cwd = crate_root, text = true },
		function(result)
			local manifest = result.code == 0 and vim.trim(result.stdout) or ""
			on_dir(manifest ~= "" and vim.fs.dirname(manifest) or crate_root)
		end
	)
end

---@type vim.lsp.Config
return {
	cmd = { "rust-analyzer" },
	filetypes = { "rust" },
	root_dir = cargo_workspace_root,
	settings = {
		["rust-analyzer"] = {
			checkOnSave = true,
			check = { command = "clippy" },
			cargo = { allFeatures = true },
		},
	},
}
