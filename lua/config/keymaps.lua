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

vim.keymap.set("n", "<C-l>", ":set hlsearch!<cr><C-l>", { desc = "Toggle search highlighting" })

vim.keymap.set("n", "<leader>q", vim.diagnostic.setloclist, { desc = "Open diagnostic [Q]uickfix list" })

vim.keymap.set("n", "<leader>xx", "<Cmd>source %<CR>", { desc = "Source current file" })
vim.keymap.set("n", "<leader>x", "<Cmd>:.lua<CR>", { desc = "Lua: execute current line" })
vim.keymap.set("v", "<leader>x", "<Cmd>:lua<CR>", { desc = "Lua: execute current selection" })

vim.keymap.set(
	"n",
	"<leader>rw",
	[[:%s/\<<C-r><C-w>\>/<C-r><C-w>/gI<Left><Left><Left>]],
	{ desc = "Replace [W]ord under cursor" }
)

vim.keymap.set("x", "<leader>rw", [["hy:%s/<C-r>h/<C-r>h/gI<Left><Left><Left>]], { desc = "Replace selection" })

vim.keymap.set("n", "<leader>sv", "<C-w>v", { desc = "Split window vertically" })
vim.keymap.set("n", "<leader>sh", "<C-w>s", { desc = "Split window horizontally" })
vim.keymap.set("n", "<leader>se", "<C-w>=", { desc = "Make splits equal size" })
vim.keymap.set("n", "<leader>sx", "<cmd>close<CR>", { desc = "Close current split" })

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

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Exit terminal mode" })

vim.keymap.set("n", "<leader>rf", function()
	local current_file = vim.fn.expand("%")
	local new_name = vim.fn.input("Rename file: ", current_file)
	if new_name ~= "" and new_name ~= current_file then
		vim.cmd("saveas " .. new_name)
		vim.cmd("e " .. new_name)
		vim.cmd("!rm " .. current_file)
		print("Renamed to " .. new_name)
	end
end, { desc = "[R]ename current [F]ile" })

vim.keymap.set("n", "[q", "<cmd>cprev<CR>", { desc = "Previous quickfix item" })
vim.keymap.set("n", "]q", "<cmd>cnext<CR>", { desc = "Next quickfix item" })
vim.keymap.set("n", "[Q", "<cmd>cfirst<CR>", { desc = "First quickfix item" })
vim.keymap.set("n", "]Q", "<cmd>clast<CR>", { desc = "Last quickfix item" })

vim.keymap.set("n", "<leader>bd", "<cmd>bd<CR>", { desc = "Close current buffer" })
vim.keymap.set("n", "<leader>ba", "<cmd>%bd|e#|bd#<CR>", { desc = "Close all but current buffer" })

vim.keymap.set("n", "J", "mzJ`z", { desc = "Join lines (keep cursor)" })
