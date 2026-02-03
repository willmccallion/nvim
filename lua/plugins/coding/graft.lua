--- @module plugins.graft
--- @brief Plugin configuration for graft.nvim.
--- @description Manages the integration of the graft AI assistant, including dependency
--- loading (plenary, nui), provider setup, and keybindings for AI operations.

local home = os.getenv("HOME")
vim.pack.add({ home .. "/projects/graft.nvim" })
vim.pack.add({ "https://github.com/nvim-lua/plenary.nvim" })
vim.pack.add({ "https://github.com/MunifTanjim/nui.nvim" })

local graft = require("graft")

graft.setup({
	default_provider = "gemini_flash",
})
