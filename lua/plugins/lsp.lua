-- lua/plugins/lsp.lua
-- Language Server Protocol setup

return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' }, -- Load LSP configs early
  dependencies = {
    -- Automatically install LSPs and formatters
    { 'williamboman/mason.nvim', config = true }, -- config = true runs mason.setup()
    'williamboman/mason-lspconfig.nvim',
    'WhoIsSethDaniel/mason-tool-installer.nvim', -- Automatically install specified tools

    -- UI for LSP progress
    { 'j-hui/fidget.nvim', tag = 'legacy', opts = {} }, -- Use `tag = 'legacy'` if you prefer the old UI

    -- Bridges nvim-cmp completion with LSP
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    -- LSP Attaching and Keymaps ------------------------------------------------
    local lsp_attach_group = vim.api.nvim_create_augroup('UserLspAttach', { clear = true })

    vim.api.nvim_create_autocmd('LspAttach', {
      group = lsp_attach_group,
      callback = function(event)
        -- Helper function for setting keymaps specific to the current buffer
        -- Matches vim.keymap.set signature more closely: map(mode, keys, func, desc)
        local map = function(mode, keys, func, desc)
          local opts = { buffer = event.buf, silent = true, noremap = true, desc = 'LSP: ' .. desc }
          vim.keymap.set(mode, keys, func, opts)
        end

        -- LSP Actions Keymaps (using Telescope for many)
        map('n', 'gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
        map('n', 'gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
        map('n', 'gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
        map('n', '<leader>D', require('telescope.builtin').lsp_type_definitions, 'Type [D]efinition')
        map('n', '<leader>ds', require('telescope.builtin').lsp_document_symbols, '[D]ocument [S]ymbols')
        map('n', '<leader>ws', require('telescope.builtin').lsp_dynamic_workspace_symbols, '[W]orkspace [S]ymbols')
        map('n', '<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
        -- *** CORRECTED CALL for code_action ***
        map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')
        map('n', 'K', vim.lsp.buf.hover, 'Hover Documentation')
        map('n', 'gD', vim.lsp.buf.declaration, '[G]oto [D]eclaration')

        -- Diagnostic Keymaps
        map('n', ']d', vim.diagnostic.goto_next, 'Next Diagnostic')
        map('n', '[d', vim.diagnostic.goto_prev, 'Previous Diagnostic')
        map('n', '<leader>de', vim.diagnostic.open_float, 'Show Diagnostic [E]rror')
        -- <leader>q is defined in core keymaps for setloclist

        local client = vim.lsp.get_client_by_id(event.data.client_id)

        -- Highlight references under cursor using document highlight provider
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_documentHighlight) then
          local highlight_augroup = vim.api.nvim_create_augroup('kickstart-lsp-highlight', { clear = false })
          vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.document_highlight,
          })
          vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
            buffer = event.buf,
            group = highlight_augroup,
            callback = vim.lsp.buf.clear_references,
          })
          -- Clean up highlight group on detach
          vim.api.nvim_create_autocmd('LspDetach', {
            group = vim.api.nvim_create_augroup('kickstart-lsp-detach', { clear = true }),
            callback = function(event2)
              -- Ensure we only clear autocmds for the buffer that detached
              if event2.buf == event.buf then
                vim.lsp.buf.clear_references()
                pcall(vim.api.nvim_clear_autocmds, { group = 'kickstart-lsp-highlight', buffer = event2.buf })
              end
            end,
          })
        end

        -- Enable inlay hints if supported (toggle with keymap)
        if client and client.supports_method(vim.lsp.protocol.Methods.textDocument_inlayHint) then
          -- *** Call map with the corrected signature ***
          map('n', '<leader>th', function()
            vim.lsp.inlay_hint.enable(not vim.lsp.inlay_hint.is_enabled({ bufnr = event.buf }))
          end, '[T]oggle Inlay [H]ints')
        end

        -- Set buffer options that LSP servers might use
        vim.bo[event.buf].omnifunc = 'v:lua.vim.lsp.omnifunc'
      end,
    })

    -- Diagnostic Configuration (icons) -----------------------------------------
    if vim.g.have_nerd_font then
      local signs = { Error = ' ', Warn = ' ', Hint = ' ', Info = ' ' } -- Example Nerd Font icons
      for type, icon in pairs(signs) do
        local hl = 'DiagnosticSign' .. type
        vim.fn.sign_define(hl, { text = icon, texthl = hl, numhl = '' })
      end
      vim.diagnostic.config({
        virtual_text = false, -- Disable virtual text diagnostics if fidget is used
        signs = { active = signs },
        update_in_insert = true,
        underline = true,
        severity_sort = true,
        float = {
          focusable = false,
          style = 'minimal',
          border = 'rounded',
          source = 'always',
          header = '',
          prefix = '',
        },
      })
    else
      -- Fallback configuration without Nerd Font icons
      vim.diagnostic.config({
        virtual_text = false,
        signs = true, -- Use default signs
        update_in_insert = true,
        underline = true,
        severity_sort = true,
        float = {
          focusable = false,
          style = 'minimal',
          border = 'rounded',
          source = 'always',
          header = '',
          prefix = '',
        },
      })
    end

    -- LSP Capabilities ---------------------------------------------------------
    local capabilities = vim.lsp.protocol.make_client_capabilities()
    -- Add capabilities from cmp_nvim_lsp
    capabilities = require('cmp_nvim_lsp').default_capabilities(capabilities)
    -- Add specific capabilities if needed
    capabilities.textDocument.completion.completionItem.snippetSupport = true

    -- Mason & Server Setup ----------------------------------------------------
    require('mason-lspconfig').setup({
      -- Define the LSPs you want to install and manage
      ensure_installed = {
        -- Add other LSPs here: 'pyright', 'gopls', 'rust_analyzer', 'tsserver', etc.
      },
      handlers = {
        -- Default handler: Setup servers with capabilities
        function(server_name)
          require('lspconfig')[server_name].setup({
            capabilities = capabilities,
            -- Add server-specific settings here if needed
          })
        end,

        -- Custom handler for lua_ls (example)
        ['lua_ls'] = function()
          require('lspconfig').lua_ls.setup({
            capabilities = capabilities,
            settings = {
              Lua = {
                runtime = {
                  -- Tell the language server which version of Lua you're using
                  version = 'LuaJIT',
                },
                diagnostics = {
                  -- Get the language server to recognize global variables like 'vim'
                  globals = { 'vim' },
                },
                workspace = {
                  -- Make the server aware of Neovim runtime files
                  library = vim.api.nvim_get_runtime_file('', true),
                  checkThirdParty = false, -- Avoid issues with third-party libs if not needed
                },
                completion = {
                  callSnippet = 'Replace', -- Enables snippet completion for functions
                },
                -- You might need additional settings based on your environment
              },
            },
          })
        end,
        -- Add custom handlers for other servers if needed
        -- ['pyright'] = function() ... end,
      },
    })

    -- Setup mason-tool-installer to ensure formatters/linters are installed
    require('mason-tool-installer').setup({
      ensure_installed = {
        -- 'stylua', -- Lua formatter
        -- Add other tools: 'black', 'isort', 'prettierd', 'eslint_d', 'clang-format' etc.
      },
    })
  end,
}
