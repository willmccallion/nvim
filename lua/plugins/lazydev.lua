-- lua/plugins/lazydev.lua
-- Optional: Improves Lua development experience for Neovim config
return {
  'folke/lazydev.nvim',
  ft = 'lua', -- Only load when editing Lua files
  opts = {
    library = {
      -- Load luvit types (vim.uv)
      { path = 'luvit-meta/library', words = { 'vim%.uv' } },
      -- You can add more libraries or specs if needed
      -- 'lazy.nvim', -- Already included by default
      -- vim.env.VIMRUNTIME -- Runtime files
    },
  },
  dependencies = {
    -- Provides the type definitions for luvit
    { 'Bilal2453/luvit-meta', lazy = true },
  },
}
