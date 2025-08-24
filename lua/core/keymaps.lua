-- ~/.config/nvim/lua/core/keymaps.lua

local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Clear search highlights
map('n', '<Esc>', '<cmd>nohlsearch<CR>', { desc = 'Clear search highlights' })

-- Disable arrow keys in normal mode
map('n', '<left>', '<cmd>echo "Use h to move!"<CR>')
map('n', '<right>', '<cmd>echo "Use l to move!"<CR>')
map('n', '<up>', '<cmd>echo "Use k to move!"<CR>')
map('n', '<down>', '<cmd>echo "Use j to move!"<CR>')

-- Window navigation
map('n', '<C-h>', '<C-w><C-h>', { desc = 'Move focus to the left window', silent = true })
map('n', '<C-l>', '<C-w><C-l>', { desc = 'Move focus to the right window', silent = true })
map('n', '<C-j>', '<C-w><C-j>', { desc = 'Move focus to the lower window', silent = true })
map('n', '<C-k>', '<C-w><C-k>', { desc = 'Move focus to the upper window', silent = true })

-- Buffer navigation
map('n', '<leader>bn', ':bnext<CR>', { desc = 'Go to next buffer', silent = true })
map('n', '<leader>bp', ':bprevious<CR>', { desc = 'Go to previous buffer', silent = true })
map('n', '<leader>bd', ':bdelete<CR>', { desc = 'Delete buffer', silent = true })

-- Show line diagnostics
map('n', '<leader>sd', vim.diagnostic.open_float, { desc = 'Show line diagnostics' })
