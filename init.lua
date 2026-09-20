--- Main entry point for the Neovim configuration.
--- Loads core config (globals, options, keymaps, autocommands) then plugins
--- organized by category: ui, coding, debug, editor, and lsp.

require("config.globals")

require("config.options")
require("config.input")
require("config.keymaps")
require("config.autocmds")
require("config.terminal")
require("config.pack_hooks")

require("plugins.ui.colourscheme")
require("plugins.ui.diagnostic")
require("plugins.ui.oil")
require("plugins.ui.treesitter_context")

require("plugins.coding.completion")
require("plugins.coding.autopairs")
require("plugins.coding.conform")
require("plugins.coding.treesitter")
require("plugins.coding.build")

require("plugins.debug.dap")

require("plugins.editor.accelerate")
require("plugins.editor.flash")
require("plugins.editor.gitsigns")
require("plugins.editor.grugfar")
require("plugins.editor.multicursor")
require("plugins.editor.surround")
require("plugins.editor.telescope")
require("plugins.editor.todo_comments")
require("plugins.editor.trouble")
require("plugins.editor.undotree")

require("plugins.lsp.fidget")
require("plugins.lsp")
