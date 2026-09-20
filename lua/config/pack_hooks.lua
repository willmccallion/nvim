--- Build and update hooks for plugins managed by vim.pack.
--- Loaded before any vim.pack.add() so installs from the lockfile trigger them too.

---@param ev vim.api.keyset.create_autocmd.callback_args
local function build_fzf_native(ev)
	-- vim.system raises rather than returning a code when the tool is absent, which a
	-- machine without build tools would otherwise surface as a bare ENOENT traceback.
	local ok, result = pcall(function()
		return vim.system({ "make" }, { cwd = ev.data.path, text = true }):wait()
	end)
	if not ok then
		vim.notify("Building telescope-fzf-native needs make: " .. tostring(result), vim.log.levels.ERROR)
		return
	end
	if result.code ~= 0 then
		vim.notify("Building telescope-fzf-native failed:\n" .. result.stderr, vim.log.levels.ERROR)
	end
end

--- Parsers must match the plugin version, so refresh them whenever it changes.
---@param ev vim.api.keyset.create_autocmd.callback_args
local function update_treesitter_parsers(ev)
	if not ev.data.active then
		vim.cmd.packadd("nvim-treesitter")
	end
	require("nvim-treesitter").update(nil, { summary = true })
end

vim.api.nvim_create_autocmd("PackChanged", {
	desc = "Run plugin build steps after install or update",
	group = vim.api.nvim_create_augroup("pack-hooks", { clear = true }),
	callback = function(ev)
		local name, kind = ev.data.spec.name, ev.data.kind
		local code_changed = kind == "install" or kind == "update"
		if name == "telescope-fzf-native.nvim" and code_changed then
			build_fzf_native(ev)
		elseif name == "nvim-treesitter" and kind == "update" then
			update_treesitter_parsers(ev)
		end
	end,
})
