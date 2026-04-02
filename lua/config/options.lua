--- @module config.options
--- @brief Core editor settings.
--- Configures UI (line numbers, sign column, cursor line), 2-space indentation,
--- smart case search, split behavior, persistent undo, and rounded window borders.

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.signcolumn = "yes"
vim.opt.cursorline = true
vim.opt.list = true
vim.opt.listchars = { tab = "» ", trail = "·", nbsp = "␣" }

vim.opt.ignorecase = true
vim.opt.smartcase = true

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

vim.opt.exrc = true

vim.opt.winborder = "rounded"

vim.opt.lazyredraw = true
