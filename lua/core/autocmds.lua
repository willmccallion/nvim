-- ~/.config/nvim/lua/core/autocmds.lua

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight yanked text
local yank_group = augroup('HighlightYank', { clear = true })
autocmd('TextYankPost', {
  group = yank_group,
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({ timeout = 200 })
  end,
  desc = 'Highlight yanked text',
})

-- On entering Neovim, if no file is specified, open Telescope oldfiles
autocmd("VimEnter", {
  pattern = "*",
  nested = true,
  callback = function()
    if vim.fn.argc() == 0 and vim.fn.isdirectory(vim.fn.getcwd()) == 0 then
      require('telescope.builtin').oldfiles()
    end
  end
})
