--- @file init.lua
--- @brief Neovim configuration entry point.
--- @details This file serves as the primary initialization script for Neovim.
--- It orchestrates the loading of core settings, keybindings, and plugin
--- configurations in a specific order to ensure a stable and functional environment.

--- Config files
require("config.globals")
require("config.options")
require("config.keymaps")
require("config.autocmds")

--- Plugins
require("plugins.lsp")
require("plugins.treesitter")
require("plugins.colourscheme")
require("plugins.completion")
require("plugins.telescope")
require("plugins.oil")
require("plugins.conform")
require("plugins.flash")
require("plugins.gitsigns")
require("plugins.todo_comments")
require("plugins.undotree")
require("plugins.accelerate")
require("plugins.diagnostic")

--- My plugin
require("plugins.graft")
