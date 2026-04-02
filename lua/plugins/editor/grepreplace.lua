--- @module plugins.editor.grepreplace
--- @brief Project-wide search and replace via Telescope.
--- <leader>sR prompts for search/replace terms, shows matches in Telescope,
--- then applies the replacement across all matched files on confirm.

vim.keymap.set("n", "<leader>sR", function()
	local search = vim.fn.input("Search: ")
	if search == "" then return end
	local replace = vim.fn.input("Replace with: ")
	if replace == "" then return end

	require("telescope.builtin").grep_string({
		search = search,
		prompt_title = "Grep: " .. search .. " → " .. replace,
		attach_mappings = function(_, map)
			map("i", "<CR>", function(prompt_bufnr)
				require("telescope.actions").send_to_qflist(prompt_bufnr)
				vim.cmd("cdo s/" .. vim.fn.escape(search, "/") .. "/" .. vim.fn.escape(replace, "/") .. "/g | update")
				vim.notify("Replaced '" .. search .. "' with '" .. replace .. "' across files")
			end)
			return true
		end,
	})
end, { desc = "Search and replace text across all project files" })
