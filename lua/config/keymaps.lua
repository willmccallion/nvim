--- @module config.keymaps
--- @brief Global keybindings and custom shortcuts configuration.
--- @description Sets up keymaps for navigation, buffer/window management, clipboard operations,
--- and various utility functions to enhance the Neovim experience.

vim.keymap.set({ "n", "x" }, "j", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set({ "n", "x" }, "k", "gk", { desc = "Navigate up (visual line)" })
vim.keymap.set({ "n", "x" }, "<Down>", "gj", { desc = "Navigate down (visual line)" })
vim.keymap.set({ "n", "x" }, "<Up>", "gk", { desc = "Navigate up (visual line)" })
vim.keymap.set("i", "<Down>", "<C-\\><C-o>gj", { desc = "Navigate down (visual line)" })
vim.keymap.set("i", "<Up>", "<C-\\><C-o>gk", { desc = "Navigate up (visual line)" })

vim.keymap.set({ "n", "x" }, "<M-S-Up>", ":move -2<cr>", { desc = "Move Line Up" })
vim.keymap.set({ "n", "x" }, "<M-S-Down>", ":move +1<cr>", { desc = "Move Line Down" })
vim.keymap.set("i", "<M-S-Up>", "<C-o>:move -2<cr>", { desc = "Move Line Up" })
vim.keymap.set("i", "<M-S-Down>", "<C-o>:move +1<cr>", { desc = "Move Line Down" })

vim.keymap.set({ "n", "x" }, "<leader>y", '"+y', { desc = "Copy to system clipboard" })
vim.keymap.set({ "n", "x" }, "<leader>p", '"+p', { desc = "Paste from system clipboard after the cursor position" })
vim.keymap.set({ "n", "x" }, "<leader>P", '"+P', { desc = "Paste from system clipboard before the cursor position" })

vim.keymap.set("n", "<leader>bb", "<C-^>", { desc = "Switch to alternate buffer" })
vim.keymap.set("n", "<leader>bn", ":bnext<cr>", { desc = "Next buffer" })
vim.keymap.set("n", "<leader>bp", ":bprevious<cr>", { desc = "Previous buffer" })

vim.keymap.set("n", "<leader>nh", ":set hlsearch!<cr>", { desc = "Toggle search highlighting" })

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic quickfix list" })

vim.keymap.set("n", "<leader>xx", "<Cmd>source %<CR>", { desc = "Source current file (reload config)" })
vim.keymap.set("n", "<leader>x", "<Cmd>:.lua<CR>", { desc = "Execute current line as Lua" })
vim.keymap.set("v", "<leader>x", "<Cmd>:lua<CR>", { desc = "Execute selection as Lua" })

vim.keymap.set(
	"n",
	"<leader>rw",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Find and replace word under cursor" }
)

vim.keymap.set("x", "<leader>rw", [["hy:%s/<C-r>h/<C-r>h/gI<Left><Left><Left>]], { desc = "Find and replace selected text" })

vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

vim.keymap.set("n", "<leader>wh", "<C-w>h", { desc = "Move to left window pane" })
vim.keymap.set("n", "<leader>wj", "<C-w>j", { desc = "Move to below window pane" })
vim.keymap.set("n", "<leader>wk", "<C-w>k", { desc = "Move to above window pane" })
vim.keymap.set("n", "<leader>wl", "<C-w>l", { desc = "Move to right window pane" })

vim.keymap.set("n", "<leader>sr", "<C-w>r", { desc = "Swap rotate window panes" })
vim.keymap.set("n", "<leader>sH", "<C-w>H", { desc = "Swap move current pane to far left" })
vim.keymap.set("n", "<leader>sL", "<C-w>L", { desc = "Swap move current pane to far right" })
vim.keymap.set("n", "<leader>sJ", "<C-w>J", { desc = "Swap move current pane to bottom" })
vim.keymap.set("n", "<leader>sK", "<C-w>K", { desc = "Swap move current pane to top" })

vim.keymap.set("n", "<leader>sm", function()
	if vim.g._zoom_restore then
		vim.cmd(vim.g._zoom_restore)
		vim.g._zoom_restore = nil
	else
		vim.g._zoom_restore = vim.fn.winrestcmd()
		vim.cmd("resize | vertical resize")
	end
end, { desc = "Toggle maximize zoom current pane" })

vim.keymap.set("n", "<C-Up>", ":resize +2<CR>", { desc = "Resize window height +" })
vim.keymap.set("n", "<C-Down>", ":resize -2<CR>", { desc = "Resize window height -" })
vim.keymap.set("n", "<C-Left>", ":vertical resize -2<CR>", { desc = "Resize window width -" })
vim.keymap.set("n", "<C-Right>", ":vertical resize +2<CR>", { desc = "Resize window width +" })

vim.keymap.set("v", "<", "<gv", { desc = "Indent left and stay in visual" })
vim.keymap.set("v", ">", ">gv", { desc = "Indent right and stay in visual" })
vim.keymap.set("x", "p", '"_dP', { desc = "Paste without overwriting register" })

vim.keymap.set("n", "<C-d>", "<C-d>zz", { desc = "Scroll down and center" })
vim.keymap.set("n", "<C-u>", "<C-u>zz", { desc = "Scroll up and center" })
vim.keymap.set("n", "n", "nzzzv", { desc = "Next search result and center" })
vim.keymap.set("n", "N", "Nzzzv", { desc = "Prev search result and center" })

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode back to normal" })

local _term_buf = nil
vim.keymap.set({ "n", "t" }, "<leader>;", function()
	if _term_buf and vim.api.nvim_buf_is_valid(_term_buf) then
		local wins = vim.fn.win_findbuf(_term_buf)
		if #wins > 0 then
			vim.api.nvim_win_close(wins[1], true)
			return
		end
	end
	vim.cmd("botright vsplit")
	if _term_buf and vim.api.nvim_buf_is_valid(_term_buf) then
		vim.api.nvim_set_current_buf(_term_buf)
	else
		vim.cmd("terminal")
		_term_buf = vim.api.nvim_get_current_buf()
	end
	vim.cmd("startinsert")
end, { desc = "Toggle terminal split on right side" })

vim.keymap.set("n", "<leader>rf", function()
	local current_file = vim.fn.expand("%")
	local new_name = vim.fn.input("Rename file: ", current_file)
	if new_name ~= "" and new_name ~= current_file then
		vim.cmd("saveas " .. new_name)
		vim.cmd("e " .. new_name)
		vim.cmd("!rm " .. current_file)
		print("Renamed to " .. new_name)
	end
end, { desc = "Rename current file" })

vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Quickfix go to previous item" })
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Quickfix go to next item" })
vim.keymap.set("n", "[Q", "<cmd>cfirst<CR>", { desc = "Quickfix go to first item" })
vim.keymap.set("n", "]Q", "<cmd>clast<CR>", { desc = "Quickfix go to last item" })
vim.keymap.set("n", "<leader>qo", "<cmd>copen<cr>", { desc = "Quickfix open list" })
vim.keymap.set("n", "<leader>qc", "<cmd>cclose<cr>", { desc = "Quickfix close list" })

vim.keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Close current buffer" })
vim.keymap.set("n", "<leader>ba", "<cmd>%bd|e#|bd#<CR>", { desc = "Close all but current buffer" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })

vim.keymap.set("v", "<Tab>", ">gv", { desc = "Indent right" })
vim.keymap.set("v", "<S-Tab>", "<gv", { desc = "Indent left" })

vim.api.nvim_create_user_command("Update", function()
	vim.pack.update()
end, { desc = "Update Neovim packages" })

vim.keymap.set("n", "<leader>pu", "<cmd>Update<cr>", { desc = "Update all plugins" })
