--- Project-wide search and replace via Telescope.
--- <leader>rp prompts for search/replace terms, shows matches in Telescope,
--- then applies the replacement across all matched files on confirm.

local substitute = require("util.substitute")

vim.keymap.set("n", "<leader>rp", function()
	local search = vim.fn.input("Search: ")
	if search == "" then
		return
	end
	local replace = vim.fn.input("Replace with: ")
	if replace == "" then
		return
	end

	require("telescope.builtin").grep_string({
		search = search,
		prompt_title = "Grep: " .. search .. " → " .. replace,
		attach_mappings = function(_, map)
			map("i", "<CR>", function(prompt_bufnr)
				require("telescope.actions").send_to_qflist(prompt_bufnr)
				local pattern = substitute.literal_pattern(search)
				local replacement = substitute.literal_replacement(replace)
				vim.cmd("cdo s/" .. pattern .. "/" .. replacement .. "/g | update")
				vim.notify("Replaced '" .. search .. "' with '" .. replace .. "' across files")
			end)
			return true
		end,
	})
end, { desc = "Replace text across all project files" })
