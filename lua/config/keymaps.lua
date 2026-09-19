--- @module config.keymaps
--- @brief Global keybindings (non-plugin).
--- Navigation, buffer/window management, clipboard, quickfix, search/replace,
--- file rename, and Lua execution shortcuts.

vim.keymap.set({ "n", "x" }, "j", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set({ "n", "x" }, "k", "gk", { desc = "Navigate up (visual line)" })
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

vim.keymap.set("n", "<leader>nh", ":set hlsearch!<cr>", { desc = "Search toggle match highlighting" })

vim.keymap.set("n", "<leader>xs", "<Cmd>source %<CR>", { desc = "Lua source current file (reload config)" })
vim.keymap.set("n", "<leader>xl", "<Cmd>:.lua<CR>", { desc = "Lua execute current line" })
vim.keymap.set("v", "<leader>x", "<Cmd>:lua<CR>", { desc = "Lua execute selection" })

vim.keymap.set(
	"n",
	"<leader>rw",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Replace word under cursor in file" }
)

vim.keymap.set(
	"x",
	"<leader>rw",
	[["hy:%s/<C-r>h/<C-r>h/gI<Left><Left><Left>]],
	{ desc = "Replace selected text in file" }
)

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

vim.keymap.set("n", "<leader>rf", function()
	local current_file = vim.fn.expand("%")
	local new_name = vim.fn.input("Rename file: ", current_file)
	if new_name ~= "" and new_name ~= current_file then
		vim.cmd("saveas " .. new_name)
		vim.cmd("e " .. new_name)
		vim.cmd("!rm " .. current_file)
		print("Renamed to " .. new_name)
	end
end, { desc = "File rename current file on disk" })

vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Quickfix go to previous item" })
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Quickfix go to next item" })
vim.keymap.set("n", "[Q", "<cmd>cfirst<CR>", { desc = "Quickfix go to first item" })
vim.keymap.set("n", "]Q", "<cmd>clast<CR>", { desc = "Quickfix go to last item" })
vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", { desc = "Quickfix open list" })
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", { desc = "Quickfix close list" })

vim.keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Buffer close current buffer" })
vim.keymap.set("n", "<leader>ba", "<cmd>%bd|e#|bd#<CR>", { desc = "Buffer close all but current buffer" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })

vim.keymap.set("v", "<Tab>", ">gv", { desc = "Indent right and stay in visual" })
vim.keymap.set("v", "<S-Tab>", "<gv", { desc = "Indent left and stay in visual" })

vim.api.nvim_create_user_command("Update", function()
	vim.pack.update()
end, { desc = "Update Neovim packages" })
