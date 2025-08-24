-- ~/.config/nvim/lua/plugins/telescope.lua
return {
  'nvim-telescope/telescope.nvim',
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    { 'nvim-telescope/telescope-fzf-native.nvim', build = 'make' },
  },
  keys = {
    { '<leader>sf', require('telescope.builtin').find_files, desc = '[S]earch [F]iles' },
    { '<leader>sg', require('telescope.builtin').live_grep, desc = '[S]earch by [G]rep' },
    { '<leader>sb', require('telescope.builtin').buffers, desc = '[S]earch [B]uffers' },
    { '<leader>sw', require('telescope.builtin').grep_string , desc = '[S]earch [W]ord'},
    { '<leader>sh', require('telescope.builtin').help_tags, desc = '[S]earch [H]elp' },
    { '<leader>s.', require('telescope.builtin').oldfiles, desc = '[S]earch Recent Files' },
  },
  config = function()
    local telescope = require('telescope')
    telescope.setup({
      defaults = {
        path_display = { 'truncate' },
      },
      extensions = {
        fzf = {
          fuzzy = true,
          override_generic_sorter = true,
          override_file_sorter = true,
          case_mode = 'smart_case',
        },
      },
    })
    telescope.load_extension('fzf')
  end,
}
