--- @module init
--- @brief Main entry point for the Neovim configuration.
--- Loads core config (globals, options, keymaps, autocommands) then plugins
--- organized by category: ui, coding, editor, and lsp.

require("config.globals")

require("config.options")
require("config.keymaps")
require("config.autocmds")

require("plugins.ui.colourscheme")
require("plugins.ui.diagnostic")
require("plugins.ui.oil")

require("plugins.coding.completion")
require("plugins.coding.autopairs")
require("plugins.coding.conform")
require("plugins.coding.treesitter")

require("plugins.editor.accelerate")
require("plugins.editor.comment")
require("plugins.editor.flash")
require("plugins.editor.gitsigns")
require("plugins.editor.grepreplace")
require("plugins.editor.multicursor")
require("plugins.editor.surround")
require("plugins.editor.telescope")
require("plugins.editor.todo_comments")
require("plugins.editor.trouble")
require("plugins.editor.undotree")

require("plugins.lsp.fidget")
require("plugins.lsp.init")
