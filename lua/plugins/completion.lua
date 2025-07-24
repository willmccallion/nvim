-- lua/plugins/completion.lua
-- Autocompletion setup using nvim-cmp

return {
  'hrsh7th/nvim-cmp',
  event = 'InsertEnter', -- Load when entering insert mode
  dependencies = {
    -- Snippet Engine & its integration with cmp
    {
      'L3MON4D3/LuaSnip',
      build = (function()
        -- Build LuaSnip with regex support (optional but recommended)
        if vim.fn.has('win32') == 1 or vim.fn.executable('make') == 0 then
          return
        end
        return 'make install_jsregexp'
      end)(),
      dependencies = {
        -- Adds friendly snippets
        -- {
        --   'rafamadriz/friendly-snippets',
        --   config = function()
        --     require('luasnip.loaders.from_vscode').lazy_load()
        --   end,
        -- },
      },
    },
    'saadparwaiz1/cmp_luasnip', -- Snippet source for nvim-cmp

    -- Other useful completion sources
    'hrsh7th/cmp-nvim-lsp', -- LSP source
    'hrsh7th/cmp-path',     -- File system path source
    'hrsh7th/cmp-buffer',   -- Buffer text source
    -- 'hrsh7th/cmp-cmdline', -- Command line completion

    -- Optional: Icons for completion items
    { 'onsails/lspkind.nvim', enabled = vim.g.have_nerd_font },
  },
  config = function()
    local cmp = require('cmp')
    local luasnip = require('luasnip')
    -- Conditionally require lspkind only if enabled, checking the flag directly
    local lspkind_ok, lspkind = pcall(require, 'lspkind')
    lspkind = vim.g.have_nerd_font and lspkind_ok and lspkind or nil

    -- *** MINIMAL CHANGE 1: Set max popup height ***
    -- Limit the completion menu to show a maximum of 5 items.
    -- You can scroll through more items if available using C-n/C-p.
    vim.o.pumheight = 5

    -- Load snippets (if using friendly-snippets or others)
    -- require('luasnip.loaders.from_vscode').lazy_load()
    luasnip.config.setup({}) -- Basic Luasnip setup

    cmp.setup({
      snippet = {
        expand = function(args)
          luasnip.lsp_expand(args.body)
        end,
      },
      completion = {
        completeopt = 'menu,menuone,noinsert',
      },
      -- *** MINIMAL CHANGE 2: Configure window appearance ***
      -- Make the completion and documentation windows borderless for a minimal look.
      window = {
        completion = cmp.config.window.bordered({ border = 'none' }),
        documentation = cmp.config.window.bordered({ border = 'none' }),
      },
      -- Keybindings for completion (your existing ones)
      mapping = cmp.mapping.preset.insert({
        ['<C-n>'] = cmp.mapping.select_next_item({ behavior = cmp.SelectBehavior.Insert }),
        ['<C-p>'] = cmp.mapping.select_prev_item({ behavior = cmp.SelectBehavior.Insert }),
        ['<C-b>'] = cmp.mapping.scroll_docs(-4),
        ['<C-f>'] = cmp.mapping.scroll_docs(4),
        ['<C-Space>'] = cmp.mapping.complete(), -- Trigger completion
        ['<C-e>'] = cmp.mapping.abort(),      -- Close completion
        ['<CR>'] = cmp.mapping.confirm({ select = true }), -- Confirm selection
        -- Snippet navigation
        ['<Tab>'] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_next_item()
          elseif luasnip.expand_or_jumpable() then
            luasnip.expand_or_jump()
          else
            fallback()
          end
        end, { 'i', 's' }), -- i = insert mode, s = select mode
        ['<S-Tab>'] = cmp.mapping(function(fallback)
          if cmp.visible() then
            cmp.select_prev_item()
          elseif luasnip.jumpable(-1) then
            luasnip.jump(-1)
          else
            fallback()
          end
        end, { 'i', 's' }),
      }),
      -- Completion sources (your existing ones)
      sources = cmp.config.sources({
        { name = 'nvim_lsp' },
        { name = 'luasnip' },
        { name = 'path' },
      }, {
        { name = 'buffer', keyword_length = 3 }, -- Use buffer source but only after 3 chars
      }),
      -- Formatting (add icons if lspkind is enabled)
      formatting = {
        -- Use lspkind only if it was successfully required and nerd fonts are enabled
        format = lspkind and lspkind.cmp_format({
          maxwidth = 50,
          ellipsis_char = '...',
          -- Show source name for each completion item (keep your commented-out option)
          -- before = function(entry, vim_item)
          --   vim_item.menu = "["..string.upper(entry.source.name).."]"
          --   return vim_item
          -- end
        }) or nil, -- Use default format if no icons/lspkind
      },
      -- Experimental features (your existing ones)
      experimental = {
        ghost_text = true, -- Show ghost text for preview
      },
    })

    -- Optional: Setup command line completion (your existing commented-out code)
    -- cmp.setup.cmdline('/', {
    --   mapping = cmp.mapping.preset.cmdline(),
    --   sources = {
    --     { name = 'buffer' }
    --   }
    -- })
    -- cmp.setup.cmdline(':', {
    --   mapping = cmp.mapping.preset.cmdline(),
    --   sources = cmp.config.sources({
    --     { name = 'path' }
    --   }, {
    --     { name = 'cmdline', keyword_length = 2 }
    --   })
    -- })
  end,
}
