-- lua/plugins/treesitter.lua
return {
  'nvim-treesitter/nvim-treesitter',
  build = ':TSUpdate', -- Command to install/update parsers
  event = { 'BufReadPre', 'BufNewFile' }, -- Load early for highlighting and indent
  dependencies = {
    -- Optional: Provides textobjects based on Treesitter nodes
    'nvim-treesitter/nvim-treesitter-textobjects',
  },
  config = function()
    require('nvim-treesitter.configs').setup({
      -- Ensure parsers for common languages are installed
      ensure_installed = {
        'bash',
        'c',
        'cpp', -- Added C++
        'diff',
        'go',
        'html',
        'javascript', -- Added JS
        'json', -- Added JSON
        'lua',
        'luadoc',
        'markdown',
        'markdown_inline',
        'python', -- Added Python
        'query', -- Required for Treesitter itself
        'regex', -- Added Regex
        'rust', -- Added Rust
        'toml', -- Added TOML
        'typescript', -- Added TS
        'vim',
        'vimdoc',
        'yaml', -- Added YAML
        -- Add other languages you frequently use
      },

      -- Install missing parsers automatically
      auto_install = true,

      -- Enable syntax highlighting
      highlight = {
        enable = true,
        -- Use Treesitter highlighting for languages not specified in `disable`
        -- disable = { 'ruby' }, -- Example: disable for ruby if causing issues
        -- Use vim regex highlighting for specific languages as fallback/extension
        additional_vim_regex_highlighting = { 'markdown' }, -- Improve markdown highlighting
      },

      -- Enable indentation based on Treesitter
      indent = {
        enable = true,
        -- disable = { 'python' }, -- Example: disable if interfering with other indent plugins
      },

      -- Optional: Configure Treesitter Textobjects
      textobjects = {
        select = {
          enable = true,
          lookahead = true, -- Makes textobjects more intuitive
          keymaps = {
            -- Default textobjects mapping keys
            ['aa'] = '@parameter.outer',
            ['ia'] = '@parameter.inner',
            ['af'] = '@function.outer',
            ['if'] = '@function.inner',
            ['ac'] = '@class.outer',
            ['ic'] = '@class.inner',
            -- Add more custom textobjects if needed
          },
        },
        move = {
          enable = true,
          set_jumps = true, -- Updates the jumplist on textobject movements
          goto_next_start = {
            [']m'] = '@function.outer',
            [']]'] = '@class.outer',
          },
          goto_next_end = {
            [']M'] = '@function.outer',
            [']['] = '@class.outer',
          },
          goto_previous_start = {
            ['[m'] = '@function.outer',
            ['[['] = '@class.outer',
          },
          goto_previous_end = {
            ['[M'] = '@function.outer',
            ['[]'] = '@class.outer',
          },
        },
        -- swap = { -- Requires nvim-treesitter/nvim-treesitter-textobjects
        --   enable = true,
        --   swap_next = { ['<leader>a'] = '@parameter.inner' },
        --   swap_previous = { ['<leader>A'] = '@parameter.inner' },
        -- },
      },

      -- Other module configurations (most are disabled by default)
      -- incremental_selection = { enable = true },
      -- matchup = { enable = true }, -- Highlight matching brackets/tags
    })
  end,
}
