-- lua/plugins/telescope.lua
return {
  'nvim-telescope/telescope.nvim',
  event = 'VimEnter', -- Load telescope relatively early
  branch = '0.1.x',
  dependencies = {
    'nvim-lua/plenary.nvim',
    {
      'nvim-telescope/telescope-fzf-native.nvim',
      build = 'make',
      cond = function() return vim.fn.executable('make') == 1 end, -- Only build if make is available
    },
    { 'nvim-telescope/telescope-ui-select.nvim' },
    { 'nvim-tree/nvim-web-devicons', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local telescope = require('telescope')
    local actions = require('telescope.actions') -- Make sure actions are required

    telescope.setup({
      defaults = {
        path_display = { 'truncate' }, -- Shorten paths in display
        mappings = {
          i = {
            ['<C-n>'] = actions.move_selection_next,
            ['<C-J>'] = actions.move_selection_next,
            ['<C-p>'] = actions.move_selection_previous,
            ['<C-K>'] = actions.move_selection_previous,
            ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
            ['<esc>'] = actions.close,
            ['<CR>'] = actions.select_default,
            ['<C-s>'] = actions.select_horizontal, -- Open in horizontal split
            ['<C-v>'] = actions.select_vertical,   -- Open in vertical split
            ['<C-t>'] = actions.select_tab,        -- Open in new tab
          },
          n = {
            ['<C-n>'] = actions.move_selection_next,
            ['<C-p>'] = actions.move_selection_previous,
            ['<C-q>'] = actions.send_selected_to_qflist + actions.open_qflist,
            ['<C-s>'] = actions.select_horizontal,
            ['<C-v>'] = actions.select_vertical,
            ['<C-t>'] = actions.select_tab,
          },
        },
        layout_strategy = 'horizontal', -- 'flex', 'horizontal', 'vertical', 'cursor'
        layout_config = {
          horizontal = { preview_width = 0.55, preview_cutoff = 120 },
          vertical = { mirror = false },
          flex = { flip_columns = 120 }
        },
        sorting_strategy = 'ascending',
        prompt_prefix = vim.g.have_nerd_font and '  ' or '> ',
        selection_caret = vim.g.have_nerd_font and ' ' or '-> ',
        entry_prefix = '  ',
        border = {},
        borderchars = { '─', '│', '─', '│', '╭', '╮', '╯', '╰' }, -- Rounded border
        color_devicons = vim.g.have_nerd_font, -- Enable only if font is present
        set_env = { ['COLORTERM'] = 'truecolor' }, -- If term supports termguicolors
      },
      pickers = {
        find_files = {
          find_command = { 'rg', '--files', '--hidden', '--glob', '!.git/*' },
          previewer = true, -- Enable previewer for find_files
        },
        live_grep = {
          previewer = true, -- Enable previewer for live_grep
        },
        buffers = {
          sort_mru = true,
          ignore_current_buffer = true,
        },
      },
      extensions = {
        ['fzf'] = {
          fuzzy = true, -- false will only do exact matching
          override_generic_sorter = true, -- override the generic sorter
          override_file_sorter = true, -- override the file sorter
          case_mode = 'smart_case', -- 'smart_case', 'ignore_case', 'respect_case'
        },
        ['ui-select'] = {
          require('telescope.themes').get_dropdown({
            -- You can add dropdown specific options here
          }),
        },
      },
      require('plugins.telescope.multigrep').setup(),
      require('plugins.floaterm').setup(),
    })

    -- Load extensions
    pcall(telescope.load_extension, 'fzf')
    pcall(telescope.load_extension, 'ui-select')

    -- Keymaps
    local builtin = require('telescope.builtin')
    local map = vim.keymap.set
    map('n', '<leader>sh', builtin.help_tags, { desc = '[S]earch [H]elp' })
    map('n', '<leader>sk', builtin.keymaps, { desc = '[S]earch [K]eymaps' })
    map('n', '<leader>sf', builtin.find_files, { desc = '[S]earch [F]iles' })
    -- map('n', '<leader>sw', builtin.grep_string, { desc = '[S]earch current [W]ord' })
    map('n', '<leader>sr', builtin.resume, { desc = '[S]earch [R]esume' })
    map('n', '<leader>s.', builtin.oldfiles, { desc = '[S]earch Recent Files ("." for repeat)' })
    map('n', '<leader>sc', builtin.commands, { desc = '[S]earch [C]ommands' })
    map('n', '<leader>so', '<cmd>Telescope lsp_document_symbols<CR>', { desc = '[S]earch [O]bjects in Project'})
    map('n', '<leader><leader>', builtin.buffers, { desc = '[ ] Find existing buffers' })

    map('n', '<leader>gc', builtin.git_commits, { desc = '[G]it [C]ommits (Project)' })
    map('n', '<leader>gC', builtin.git_bcommits, { desc = '[G]it buffer [C]ommits' }) -- Commits for current file
    map('n', '<leader>gb', builtin.git_branches, { desc = '[G]it [B]ranches' })
    map('n', '<leader>gs', builtin.git_status, { desc = '[G]it [S]tatus' })

    map('n', '<leader>/', function()
      builtin.current_buffer_fuzzy_find(require('telescope.themes').get_dropdown({
        winblend = 10,
        previewer = false,
      }))
    end, { desc = '[/] Fuzzily search in current buffer' })

    map('n', '<leader>s/', function()
      builtin.live_grep({
        grep_open_files = true,
        prompt_title = 'Live Grep in Open Files',
      })
    end, { desc = '[S]earch [/] in Open Files' })

    vim.keymap.set('n', '<leader>q', function()
      builtin.diagnostics()
    end, {desc = 'Search Diagnostics'})

    vim.keymap.set('n', '<leader>sH', function()
      builtin.highlights()
    end, { desc = '[S]earch [H]ighlights' })

    map('n', '<leader>sn', function()
      builtin.find_files({ cwd = vim.fn.stdpath('config') })
    end, { desc = '[S]earch [N]eovim files' })
  end,
}
