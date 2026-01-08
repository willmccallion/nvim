vim.pack.add({
  'https://github.com/nvim-lua/plenary.nvim',
  'https://github.com/nvim-telescope/telescope.nvim',
  'https://github.com/nvim-telescope/telescope-fzf-native.nvim',
  'https://github.com/nvim-telescope/telescope-ui-select.nvim',
  'https://github.com/nvim-tree/nvim-web-devicons'
})

local telescope = require('telescope')
local actions = require('telescope.actions')

telescope.setup({
  defaults = {
    path_display = { 'truncate' },
    mappings = {
      i = { ['<C-j>'] = actions.move_selection_next, ['<C-k>'] = actions.move_selection_previous },
    },
    layout_strategy = 'horizontal',
    layout_config = { horizontal = { preview_width = 0.55 } },
    borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' },
    prompt_prefix = vim.g.have_nerd_font and '  ' or '> ',
    selection_caret = vim.g.have_nerd_font and ' ' or '-> ',
  },
  extensions = {
    ['fzf'] = { override_generic_sorter = true, override_file_sorter = true, case_mode = 'smart_case' },
    ['ui-select'] = { require('telescope.themes').get_dropdown({}) },
  },
})

pcall(telescope.load_extension, 'fzf')
pcall(telescope.load_extension, 'ui-select')

local builtin = require('telescope.builtin')
local map = vim.keymap.set
map('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
map('n', '<leader>sg', builtin.live_grep, { desc = '[S]earch by [G]rep' })
map('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
map('n', '<leader>/', builtin.buffers, { desc = 'Find open buffers' })
map('n', '<leader><leader>', function()
    builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({
      winblend = 10,
      previewer = false,
    }))
  end, { desc = '[/] Fuzzily search in current buffer' })
