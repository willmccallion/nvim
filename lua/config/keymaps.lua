-- lua/config/keymaps.lua
-- Core Neovim keymaps (non-plugin specific)

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- General
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlights' })

-- Disable Arrow Keys in Normal Mode
map('n', '<left>', '<cmd>echo "Use h to move!!"<CR>')
map('n', '<right>', '<cmd>echo "Use l to move!!"<CR>')
map('n', '<up>', '<cmd>echo "Use k to move!!"<CR>')
map('n', '<down>', '<cmd>echo "Use j to move!!"<CR>')

-- Window Navigation
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window', silent = true })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window', silent = true })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window', silent = true })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window', silent = true })

-- Buffer Navigation
map('n', '<leader>bn', ':bnext<CR>', { desc = 'Go to [B]uffer [N]ext', silent = true })
map('n', '<leader>bp', ':bprevious<CR>', { desc = 'Go to [B]uffer [P]revious', silent = true })
map('n', '<leader>bd', ':bdelete<CR>', { desc = 'Delete [B]uffer', silent = true })
-- Add terminal mode mapping if needed, but often closing the shell normally is better
-- map('t', '<leader>bd', '<C-\\><C-n>:bdelete!<CR>', { desc = 'Force Delete [B]uffer (from terminal)', silent = true })

-- Add other core keymaps here
map('n', '<leader>E', 'ea')
-- In your Neovim configuration (e.g., init.lua or lua/your_config/keymaps.lua)

-- Ensure you have a leader key set, e.g.,
-- vim.g.mapleader = ' ' -- Set leader key to space (common choice)
-- vim.g.maplocalleader = ' ' -- Optional: set localleader too

-- Define the keymap
vim.keymap.set('n', '<leader>sd', vim.diagnostic.open_float, {
  noremap = true, -- Use non-recursive mapping
  silent = true,  -- Don't echo the command
  desc = 'Show Line Diagnostics' -- Description for which-key or help
})

map('n', '<leader>fr', ":%s/", { desc = "Find and replace."})
