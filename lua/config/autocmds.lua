-- lua/config/autocmds.lua
-- Global autocommands

local augroup = vim.api.nvim_create_augroup
local autocmd = vim.api.nvim_create_autocmd

-- Highlight yanked text
local yank_group = augroup('HighlightYank', { clear = true })
autocmd('TextYankPost', {
  group = yank_group,
  pattern = '*',
  callback = function()
    vim.highlight.on_yank({ timeout = 200 }) -- Highlight for 200ms
  end,
  desc = 'Highlight yanked text',
})

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    local hl = vim.api.nvim_set_hl
    hl(0, "TelescopeNormal", { bg = "none" })
    hl(0, "TelescopeBorder", { bg = "none" })
    hl(0, "TelescopePromptNormal", { bg = "none" })
    hl(0, "TelescopePromptBorder", { bg = "none" })
    hl(0, "TelescopeResultsNormal", { bg = "none" })
    hl(0, "TelescopeResultsBorder", { bg = "none" })
    hl(0, "TelescopePreviewNormal", { bg = "none" })
    hl(0, "TelescopePreviewBorder", { bg = "none" })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    if vim.fn.argc() == 0 then
      require('telescope.builtin').oldfiles()
    end
  end
})

