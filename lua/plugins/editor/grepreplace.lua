--- Project-wide search and replace via Telescope.
--- <leader>rp prompts for search/replace terms, shows matches in Telescope,
--- then applies the replacement across all matched files on confirm.
--- An empty replacement deletes the matches; <Esc> at either prompt cancels.

local substitute = require("util.substitute")

---@param search string
---@param replace string
local function pick_and_replace(search, replace)
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
end

vim.keymap.set("n", "<leader>rp", function()
	vim.ui.input({ prompt = "Search: " }, function(search)
		if not search or search == "" then
			return
		end
		vim.ui.input({ prompt = "Replace with: " }, function(replace)
			if not replace then
				return
			end
			pick_and_replace(search, replace)
		end)
	end)
end, { desc = "Replace text across all project files" })
