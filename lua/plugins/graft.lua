--- @file graft.lua
--- @brief Configuration and initialization for the graft.nvim AI assistant plugin.
--- @details This script manages the loading of the graft.nvim plugin from a local path,
--- ensures its dependencies are available, and sets up the default configuration and keybindings.

local home = os.getenv("HOME")
vim.pack.add({ home .. "/projects/graft.nvim" })
vim.pack.add({ "https://github.com/nvim-lua/plenary.nvim" })
vim.pack.add({ "https://github.com/MunifTanjim/nui.nvim" })

local graft = require("graft")

graft.setup({
	default_provider = "gemini_flash",
})

vim.keymap.set({ "n", "v" }, "<leader>aa", graft.start, { desc = "[A]I [A]ssistant" })
vim.keymap.set("n", "<leader>am", graft.select_model, { desc = "[A]I [M]odel Select" })
vim.keymap.set("n", "<leader>as", graft.stop_job, { desc = "[A]I [S]top" })
