-- ~/.config/nvim/lua/core/options.lua

local opt = vim.opt

-- Line Numbers
opt.number = true
opt.relativenumber = true

-- Appearance
opt.termguicolors = true    -- Enable 24-bit RGB colors
opt.cursorline = true       -- Highlight the current line
opt.laststatus = 3          -- Use a global statusline
opt.showmode = false        -- Hide the mode text (handled by statusline)
opt.signcolumn = 'yes'      -- Always show the sign column
opt.scrolloff = 10          -- Keep 10 lines visible above/below cursor

-- Indentation
opt.tabstop = 4             -- Number of visual spaces per TAB
opt.shiftwidth = 4          -- Number of spaces for autoindent
opt.softtabstop = 4         -- Number of spaces TAB inserts/deletes
opt.expandtab = true        -- Use spaces instead of tabs
opt.breakindent = true      -- Maintain indentation when wrapping lines

-- Searching
opt.ignorecase = true       -- Ignore case when searching...
opt.smartcase = true        -- ...unless the pattern has uppercase letters

-- Behavior
opt.mouse = 'a'             -- Enable mouse support in all modes
opt.clipboard = 'unnamedplus' -- Use system clipboard
opt.undofile = true         -- Enable persistent undo
opt.splitright = true       -- Open vertical splits to the right
opt.splitbelow = true       -- Open horizontal splits below
opt.inccommand = 'split'    -- Preview substitutions live
opt.updatetime = 250        -- Faster completion
opt.timeoutlen = 300        -- Time to wait for key codes
