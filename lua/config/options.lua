-- lua/config/options.lua
-- Global settings and Neovim options

vim.g.mapleader = ' '
vim.g.maplocalleader = ' '

vim.g.have_nerd_font = true -- Set this to false if you don't have a Nerd Font installed

vim.opt.number = true         -- Show line numbers
vim.opt.relativenumber = true -- Show relative line numbers

vim.opt.mouse = 'a' -- Enable mouse support in all modes
vim.opt.laststatus = 0

vim.opt.showmode = false -- Don't show the mode in the command line (handled by status line)

-- Set clipboard to use system clipboard
vim.schedule(function()
  vim.opt.clipboard = 'unnamedplus'
end)

vim.opt.breakindent = true -- Maintain indentation when wrapping lines

vim.opt.undofile = true -- Enable persistent undo

-- Searching
vim.opt.ignorecase = true -- Ignore case when searching...
vim.opt.smartcase = true  -- ...unless the search pattern contains uppercase letters

vim.opt.signcolumn = 'yes' -- Always show the sign column

vim.opt.updatetime = 250 -- Faster completion (default is 4000ms)
vim.opt.timeoutlen = 300 -- Time to wait for key codes (<leader> waits 300ms)

-- Window Splitting
vim.opt.splitright = true -- Open vertical splits to the right
vim.opt.splitbelow = true -- Open horizontal splits below

-- Appearance
vim.opt.list = true -- Show whitespace characters (initially, can be toggled)
vim.opt.listchars = { tab = '» ', trail = '·', nbsp = '␣' } -- Configure list characters

vim.opt.inccommand = 'split' -- Preview substitutions live, as you type

vim.opt.cursorline = true -- Highlight the current line

-- Indentation
vim.opt.tabstop = 4     -- Number of visual spaces per TAB
vim.opt.shiftwidth = 4  -- Number of spaces for autoindent
vim.opt.expandtab = true -- Use spaces instead of tabs
vim.opt.softtabstop = 4 -- Number of spaces TAB inserts/deletes in Insert mode

-- Turn off list initially if preferred (can be toggled)
vim.opt.list = false

vim.opt.scrolloff = 10 -- Keep 10 lines visible above/below cursor when scrolling

vim.opt.termguicolors = true -- Enable 24-bit RGB colors
