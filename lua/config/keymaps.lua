--- Global keybindings (non-plugin).
--- Grouped by domain: editing and navigation, clipboard, buffer, window,
--- replace/rename, quickfix, option toggles, and Lua.

local substitute = require("util.substitute")

vim.keymap.set("x", "j", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set("x", "k", "gk", { desc = "Navigate up (visual line)" })
vim.keymap.set({ "n", "x" }, "<Down>", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set({ "n", "x" }, "<Up>", "gk", { desc = "Navigate up (visual line)" })
vim.keymap.set("i", "<Down>", "<C-\\><C-o>gj", { desc = "Navigate down (visual line)" })
vim.keymap.set("i", "<Up>", "<C-\\><C-o>gk", { desc = "Navigate up (visual line)" })

vim.keymap.set("n", "<M-S-Up>", "<Cmd>move -2<CR>", { desc = "Move line up" })
vim.keymap.set("n", "<M-S-Down>", "<Cmd>move +1<CR>", { desc = "Move line down" })
vim.keymap.set("x", "<M-S-Up>", ":move '<-2<CR>gv", { desc = "Move selected lines up" })
vim.keymap.set("x", "<M-S-Down>", ":move '>+1<CR>gv", { desc = "Move selected lines down" })
vim.keymap.set("i", "<M-S-Up>", "<Cmd>move -2<CR>", { desc = "Move line up" })
vim.keymap.set("i", "<M-S-Down>", "<Cmd>move +1<CR>", { desc = "Move line down" })

vim.keymap.set("x", "<", "<gv", { desc = "Indent left and stay in visual" })
vim.keymap.set("x", ">", ">gv", { desc = "Indent right and stay in visual" })
vim.keymap.set("x", "p", "P", { desc = "Paste without overwriting register" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Search next match and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Search previous match and center" })

vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "Clipboard copy to system clipboard" })
vim.keymap.set({ "n", "x" }, "<leader>p", '"+p', { desc = "Clipboard paste from system clipboard after cursor" })
vim.keymap.set({ "n", "x" }, "<leader>P", '"+P', { desc = "Clipboard paste from system clipboard before cursor" })

vim.keymap.set("n", "<leader>bb", "<C-^>", { desc = "Buffer switch to alternate (last used) buffer" })
vim.keymap.set("n", "<leader>bn", "<Cmd>bnext<CR>", { desc = "Buffer go to next buffer" })
vim.keymap.set("n", "<leader>bp", "<Cmd>bprevious<CR>", { desc = "Buffer go to previous buffer" })

vim.keymap.set("n", "<leader>bd", "<Cmd>bdelete<CR>", { desc = "Buffer close current buffer" })

--- Keeps buffers with unsaved changes and terminals, whose shells would be killed.
local function close_other_buffers()
	local current = vim.api.nvim_get_current_buf()
	local kept = {}
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if buf ~= current and vim.bo[buf].buflisted then
			if vim.bo[buf].modified or vim.bo[buf].buftype == "terminal" then
				table.insert(kept, vim.fn.fnamemodify(vim.api.nvim_buf_get_name(buf), ":t"))
			else
				vim.api.nvim_buf_delete(buf, {})
			end
		end
	end
	if #kept > 0 then
		vim.notify("Kept (unsaved or terminal): " .. table.concat(kept, ", "), vim.log.levels.WARN)
	end
end

vim.keymap.set("n", "<leader>ba", close_other_buffers, { desc = "Buffer close all but current buffer" })

vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Window split vertically" })
vim.keymap.set("n", "<leader>ws", "<C-w>s", { desc = "Window split horizontally" })
vim.keymap.set("n", "<leader>we", "<C-w>=", { desc = "Window make splits equal size" })
vim.keymap.set("n", "<leader>wx", "<Cmd>close<CR>", { desc = "Window close current split" })

vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Window move to left pane" })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Window move to below pane" })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Window move to above pane" })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Window move to right pane" })

vim.keymap.set("n", "<leader>wr", "<C-w>r", { desc = "Window rotate panes" })
vim.keymap.set("n", "<leader>wH", "<C-w>H", { desc = "Window swap current pane to far left" })
vim.keymap.set("n", "<leader>wL", "<C-w>L", { desc = "Window swap current pane to far right" })
vim.keymap.set("n", "<leader>wJ", "<C-w>J", { desc = "Window swap current pane to bottom" })
vim.keymap.set("n", "<leader>wK", "<C-w>K", { desc = "Window swap current pane to top" })

---@type string? winrestcmd() output captured before maximizing
local layout_before_zoom = nil

vim.keymap.set("n", "<leader>wm", function()
	if layout_before_zoom then
		vim.cmd(layout_before_zoom)
		layout_before_zoom = nil
	else
		layout_before_zoom = vim.fn.winrestcmd()
		vim.cmd("resize | vertical resize")
	end
end, { desc = "Window toggle maximize zoom current pane" })

vim.keymap.set("n", "<C-Up>", "<Cmd>resize +2<CR>", { desc = "Window increase height" })
vim.keymap.set("n", "<C-Down>", "<Cmd>resize -2<CR>", { desc = "Window decrease height" })
vim.keymap.set("n", "<C-Left>", "<Cmd>vertical resize -2<CR>", { desc = "Window decrease width" })
vim.keymap.set("n", "<C-Right>", "<Cmd>vertical resize +2<CR>", { desc = "Window increase width" })

vim.keymap.set(
	"n",
	"<leader>rw",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Replace word under cursor in file" }
)

vim.keymap.set("x", "<leader>rw", function()
	local selected =
		table.concat(vim.fn.getregion(vim.fn.getpos("v"), vim.fn.getpos("."), { type = vim.fn.mode() }), "\n")
	local command = ":%s/"
		.. substitute.literal_pattern(selected)
		.. "/"
		.. substitute.literal_replacement(selected)
		.. "/gI"
	vim.api.nvim_feedkeys(vim.keycode("<Esc>") .. command .. vim.keycode("<Left><Left><Left>"), "ni", false)
end, { desc = "Replace selected text in file" })

---@param err string|lsp.ResponseError
---@return string
local function lsp_error_message(err)
	return type(err) == "table" and err.message or tostring(err)
end

--- Renames on disk (keeping permissions), then points the buffer at the new path.
--- Language servers first update references (e.g. `mod` lines), left unsaved like oil's.
local function rename_current_file()
	local old_path = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or old_path == "" or not vim.uv.fs_stat(old_path) then
		vim.notify("Current buffer is not a file on disk", vim.log.levels.WARN)
		return
	end

	local input = vim.fn.input({ prompt = "Rename file: ", default = old_path, completion = "file" })
	if input == "" then
		return
	end
	local new_path = vim.fn.fnamemodify(input, ":p")
	if new_path == old_path then
		return
	end
	if vim.uv.fs_stat(new_path) then
		vim.notify(new_path .. " already exists", vim.log.levels.ERROR)
		return
	end

	local lsp_files = require("oil.lsp.workspace")
	local moves = { [old_path] = new_path }
	local _, lsp_err = lsp_files.will_rename_files(moves)
	if lsp_err then
		vim.notify("Language servers did not update references: " .. lsp_error_message(lsp_err), vim.log.levels.WARN)
	end

	vim.fn.mkdir(vim.fs.dirname(new_path), "p")
	local ok, err = vim.uv.fs_rename(old_path, new_path)
	if not ok then
		vim.notify("Rename failed: " .. err, vim.log.levels.ERROR)
		return
	end
	vim.api.nvim_buf_set_name(0, new_path)
	vim.cmd("silent write!")
	lsp_files.did_rename_files(moves)

	local stale_buf = vim.fn.bufnr(old_path)
	if stale_buf ~= -1 then
		vim.api.nvim_buf_delete(stale_buf, {})
	end
	vim.notify("Renamed to " .. vim.fn.fnamemodify(new_path, ":~:."))
end

vim.keymap.set("n", "<leader>rf", rename_current_file, { desc = "Rename current file on disk" })

local function toggle_quickfix()
	if vim.fn.getqflist({ winid = 0 }).winid ~= 0 then
		vim.cmd.cclose()
	else
		vim.cmd.copen()
	end
end

vim.keymap.set("n", "<leader>q", toggle_quickfix, { desc = "Quickfix toggle list" })

vim.keymap.set("n", "<leader>oh", "<Cmd>set hlsearch!<CR>", { desc = "Option toggle search match highlighting" })

vim.keymap.set("n", "<leader>Ls", "<Cmd>source %<CR>", { desc = "Lua source current file (reload config)" })
vim.keymap.set("n", "<leader>Ll", "<Cmd>.lua<CR>", { desc = "Lua execute current line" })
vim.keymap.set("x", "<leader>L", ":lua<CR>", { desc = "Lua execute selection" })

vim.api.nvim_create_user_command("Update", function()
	vim.pack.update()
end, { desc = "Update Neovim packages" })
