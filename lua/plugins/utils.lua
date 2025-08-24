-- ~/.config/nvim/lua/plugins/utils.lua
return {
  -- Git integration
  { 'lewis6991/gitsigns.nvim', event = { 'BufReadPost', 'BufNewFile' }, opts = {} },
  { 'tpope/vim-fugitive', cmd = 'Git' },

  -- File explorer
  { 'stevearc/oil.nvim', dependencies = { 'nvim-tree/nvim-web-devicons' },
    keys = { { '<leader>e', '<cmd>Oil<CR>', desc = 'Open file explorer' } },
    opts = {}
  },

  -- Undo tree
  { 'mbbill/undotree', cmd = 'UndotreeToggle',
    keys = { { '<leader>ut', '<cmd>UndotreeToggle<CR>', desc = 'Toggle UndoTree' } }
  },

  -- Fast motion
  { 'folke/flash.nvim', event = 'VeryLazy',
    opts = {},
    keys = {
      { 's', mode = { 'n', 'x', 'o' }, function() require('flash').jump() end, desc = 'Flash Jump' },
    },
  },

  -- Auto-detect indentation
  { 'tpope/vim-sleuth', event = 'BufReadPost' },

  -- Restore cursor position
  { 'farmergreg/vim-lastplace', event = 'BufReadPre' },
}
