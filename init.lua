--- @module init
--- @brief Main entry point for the Neovim configuration.
--- @description This module orchestrates the loading sequence of the entire Neovim setup,
--- including global variables, core options, keybindings, autocommands, and
--- individual plugin configurations.

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
