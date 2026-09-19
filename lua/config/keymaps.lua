--- Global keybindings (non-plugin).
--- Navigation, buffer/window management, clipboard, quickfix, search/replace,
--- file rename, and Lua execution shortcuts.

local substitute = require("util.substitute")

vim.keymap.set("x", "j", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set("x", "k", "gk", { desc = "Navigate up (visual line)" })
vim.keymap.set({ "n", "x" }, "<Down>", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set({ "n", "x" }, "<Up>", "gk", { desc = "Navigate up (visual line)" })
vim.keymap.set("i", "<Down>", "<C-\\><C-o>gj", { desc = "Navigate down (visual line)" })
vim.keymap.set("i", "<Up>", "<C-\\><C-o>gk", { desc = "Navigate up (visual line)" })

vim.keymap.set({ "n", "x" }, "<M-S-Up>", ":move -2<cr>", { desc = "Move line up" })
vim.keymap.set({ "n", "x" }, "<M-S-Down>", ":move +1<cr>", { desc = "Move line down" })
vim.keymap.set("i", "<M-S-Up>", "<C-o>:move -2<cr>", { desc = "Move line up" })
vim.keymap.set("i", "<M-S-Down>", "<C-o>:move +1<cr>", { desc = "Move line down" })

vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "Clipboard copy to system clipboard" })
vim.keymap.set({ "n", "x" }, "<leader>p", '"+p', { desc = "Clipboard paste from system clipboard after cursor" })
vim.keymap.set({ "n", "x" }, "<leader>P", '"+P', { desc = "Clipboard paste from system clipboard before cursor" })

vim.keymap.set("n", "<leader>bb", "<C-^>", { desc = "Buffer switch to alternate (last used) buffer" })
vim.keymap.set("n", "<leader>bn", ":bnext<cr>", { desc = "Buffer go to next buffer" })
vim.keymap.set("n", "<leader>bp", ":bprevious<cr>", { desc = "Buffer go to previous buffer" })

vim.keymap.set("n", "<leader>oh", "<Cmd>set hlsearch!<CR>", { desc = "Option toggle search match highlighting" })

vim.keymap.set("n", "<leader>Ls", "<Cmd>source %<CR>", { desc = "Lua source current file (reload config)" })
vim.keymap.set("n", "<leader>Ll", "<Cmd>:.lua<CR>", { desc = "Lua execute current line" })
vim.keymap.set("v", "<leader>L", "<Cmd>:lua<CR>", { desc = "Lua execute selection" })

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

vim.keymap.set("n", "<leader>wv", "<C-w>v", { desc = "Window split vertically" })
vim.keymap.set("n", "<leader>ws", "<C-w>s", { desc = "Window split horizontally" })
vim.keymap.set("n", "<leader>we", "<C-w>=", { desc = "Window make splits equal size" })
vim.keymap.set("n", "<leader>wx", "<cmd>close<CR>", { desc = "Window close current split" })

vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Window move to left pane" })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Window move to below pane" })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Window move to above pane" })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Window move to right pane" })

vim.keymap.set("n", "<leader>wr", "<C-w>r", { desc = "Window rotate panes" })
vim.keymap.set("n", "<leader>wH", "<C-w>H", { desc = "Window swap current pane to far left" })
vim.keymap.set("n", "<leader>wL", "<C-w>L", { desc = "Window swap current pane to far right" })
vim.keymap.set("n", "<leader>wJ", "<C-w>J", { desc = "Window swap current pane to bottom" })
vim.keymap.set("n", "<leader>wK", "<C-w>K", { desc = "Window swap current pane to top" })

vim.keymap.set("n", "<leader>wm", function()
	if vim.g._zoom_restore then
		vim.cmd(vim.g._zoom_restore)
		vim.g._zoom_restore = nil
	else
		vim.g._zoom_restore = vim.fn.winrestcmd()
		vim.cmd("resize | vertical resize")
	end
end, { desc = "Window toggle maximize zoom current pane" })

vim.keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Window increase height" })
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Window decrease height" })
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Window decrease width" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Window increase width" })

vim.keymap.set("v", "<", "<gv", { desc = "Indent left and stay in visual" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and stay in visual" })
vim.keymap.set("x", "p", '"_dP', { desc = "Paste without overwriting register" })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Search next match and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Search previous match and center" })

--- Renames on disk (keeping permissions), then points the buffer at the new path.
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

	vim.fn.mkdir(vim.fs.dirname(new_path), "p")
	local ok, err = vim.uv.fs_rename(old_path, new_path)
	if not ok then
		vim.notify("Rename failed: " .. err, vim.log.levels.ERROR)
		return
	end
	vim.api.nvim_buf_set_name(0, new_path)
	vim.cmd("silent write!")

	local stale_buf = vim.fn.bufnr(old_path)
	if stale_buf ~= -1 then
		vim.api.nvim_buf_delete(stale_buf, {})
	end
	vim.notify("Renamed to " .. vim.fn.fnamemodify(new_path, ":~:."))
end

vim.keymap.set("n", "<leader>rf", rename_current_file, { desc = "Rename current file on disk" })

vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", { desc = "Quickfix open list" })
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", { desc = "Quickfix close list" })

vim.keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Buffer close current buffer" })
vim.keymap.set("n", "<leader>ba", "<cmd>%bd|e#|bd#<CR>", { desc = "Buffer close all but current buffer" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })

vim.api.nvim_create_user_command("Update", function()
	vim.pack.update()
end, { desc = "Update Neovim packages" })
