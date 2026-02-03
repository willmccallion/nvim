--- @file treesitter.lua
--- @brief Configuration and setup for nvim-treesitter.
--- @details This file manages the installation of the nvim-treesitter plugin,
--- configures the supported language parsers, and establishes an
--- automated update mechanism for parsers when the plugin is updated.

vim.pack.add({
	{
		src = "https://github.com/nvim-treesitter/nvim-treesitter",
		version = "master",
	},
})

require("nvim-treesitter.configs").setup({
	ensure_installed = {
		"lua",
		"vim",
		"vimdoc",
		"c",
		"cpp",
		"rust",
		"python",
		"javascript",
		"typescript",
		"markdown",
		"markdown_inline",
		"bash",
	},
	sync_install = false,
	auto_install = true,
	highlight = {
		enable = true,
		additional_vim_regex_highlighting = false,
	},
	indent = {
		enable = true,
	},
})

vim.api.nvim_create_autocmd("PackChanged", {
	desc = "Handle nvim-treesitter updates",
	group = vim.api.nvim_create_augroup("nvim-treesitter-pack-changed-update-handler", { clear = true }),
	--- @brief Callback function executed when a package change event occurs.
	--- @param event table The event context containing data about the package change.
	--- @return nil
	callback = function(event)
		if event.data.kind == "update" and event.data.spec.name == "nvim-treesitter" then
			vim.notify("nvim-treesitter updated, running TSUpdate...", vim.log.levels.INFO)
			local ok = pcall(vim.cmd, "TSUpdate")
			if ok then
				vim.notify("TSUpdate completed successfully!", vim.log.levels.INFO)
			else
				vim.notify("TSUpdate command not available yet, skipping", vim.log.levels.WARN)
			end
		end
	end,
})
