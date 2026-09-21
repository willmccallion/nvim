--- Core editor settings.
--- Configures UI (line numbers, sign column, cursor line), 2-space indentation,
--- smart case search, split behavior, persistent undo, and rounded window borders.

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
vim.opt.mouse = ""

-- Accelerated j/k covers ground fast enough that a cursor on the last visible
-- line gives no warning that the window is about to end.
vim.opt.scrolloff = 4

vim.opt.ignorecase = true
vim.opt.smartcase = true

-- Diagnostic virtual lines follow the cursor on CursorHold, so the default 4s reads as broken.
vim.opt.updatetime = 250

vim.opt.inccommand = "split"

vim.opt.wrap = true
vim.opt.breakindent = true

vim.opt.expandtab = true
vim.opt.tabstop = 2
vim.opt.softtabstop = 2
vim.opt.shiftwidth = 2

vim.opt.splitright = true
vim.opt.splitbelow = true

vim.opt.undofile = true

--- Folds follow the syntax tree. A language server that reports folding ranges
--- takes over per window in lua/plugins/lsp/init.lua, since it knows about things
--- the tree does not, like a run of imports. Files open with every fold up:
--- folding is here to collapse what you choose, not to hide a file on arrival.
vim.opt.foldmethod = "expr"
vim.opt.foldexpr = "v:lua.vim.treesitter.foldexpr()"
vim.opt.foldlevelstart = 99

vim.opt.exrc = true

vim.opt.winborder = "rounded"
