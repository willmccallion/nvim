--- Search and replace via grug-far, in a split beside the code.
--- <leader>rw works on the current file and <leader>rp on the whole project;
--- both prefill from the word under the cursor, or from the selection in visual
--- mode. Matches are listed with the replacement rendered in place, and nothing
--- touches disk until <C-s> syncs it back.
---
--- Buffer keys are grug-far's own <localleader> ones, which "," makes reachable.

vim.pack.add({ "https://github.com/MagicDuck/grug-far.nvim" })

local grug_far = require("grug-far")

grug_far.setup({
	windowCreationCommand = "vsplit",
	keymaps = {
		-- <Down>/<Up> are gj/gk here, which a result list should not inherit.
		openNextLocation = { n = "<C-j>" },
		openPrevLocation = { n = "<C-k>" },
		-- The buffer opens in insert mode on Search, so field movement has to work there too.
		nextInput = { n = "<Tab>", i = "<Tab>" },
		prevInput = { n = "<S-Tab>", i = "<S-Tab>" },
	},
})

--- Path of the current buffer, or nil when it is not a file on disk.
---@return string?
local function current_file()
	local path = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or path == "" or not vim.uv.fs_stat(path) then
		vim.notify("Current buffer is not a file on disk", vim.log.levels.WARN)
		return nil
	end
	-- grug-far splits its Paths field on unescaped spaces.
	return (vim.fn.expand("%"):gsub(" ", "\\ "))
end

--- Reads the selection and leaves visual mode before returning. The "x" flag is
--- what makes the <Esc> take effect now: queued, it would arrive after grug-far
--- had already opened its window, landing in that buffer instead.
---@return string
local function take_visual_selection()
	local lines = vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() })
	vim.api.nvim_feedkeys(vim.keycode("<Esc>"), "nx", false)
	return table.concat(lines, "\n")
end

--- rg needs --multiline to match a pattern that spans a line break.
---@param search string
---@param whole_word boolean
---@return string
local function literal_flags(search, whole_word)
	local flags = { "--fixed-strings" }
	if whole_word then
		table.insert(flags, "--word-regexp")
	end
	if search:find("\n", 1, true) then
		table.insert(flags, "--multiline")
	end
	return table.concat(flags, " ")
end

---@param search string
---@param whole_word boolean
---@param paths string? nil searches the whole project
local function replace(search, whole_word, paths)
	grug_far.open({
		prefills = { search = search, paths = paths, flags = literal_flags(search, whole_word) },
	})
end

vim.keymap.set("n", "<leader>rw", function()
	local file = current_file()
	if file then
		replace(vim.fn.expand("<cword>"), true, file)
	end
end, { desc = "Replace word under cursor in this file" })

vim.keymap.set("x", "<leader>rw", function()
	local search = take_visual_selection()
	local file = current_file()
	if file then
		replace(search, false, file)
	end
end, { desc = "Replace selected text in this file" })

vim.keymap.set("n", "<leader>rp", function()
	replace(vim.fn.expand("<cword>"), true, nil)
end, { desc = "Replace word under cursor across all project files" })

vim.keymap.set("x", "<leader>rp", function()
	local search = take_visual_selection()
	replace(search, false, nil)
end, { desc = "Replace selected text across all project files" })
