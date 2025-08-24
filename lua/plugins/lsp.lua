-- ~/.config/nvim/lua/plugins/lsp.lua

return {
  'neovim/nvim-lspconfig',
  event = { 'BufReadPre', 'BufNewFile' },
  dependencies = {
    { 'williamboman/mason.nvim', config = true },
    'williamboman/mason-lspconfig.nvim',
    { 'j-hui/fidget.nvim', tag = 'legacy', opts = {} },
    'hrsh7th/cmp-nvim-lsp',
  },
  config = function()
    local on_attach = function(client, bufnr)
      local map = function(mode, keys, func, desc)
        vim.keymap.set(mode, keys, func, { buffer = bufnr, silent = true, desc = 'LSP: ' .. desc })
      end

      map('n', 'gd', require('telescope.builtin').lsp_definitions, '[G]oto [D]efinition')
      map('n', 'gr', require('telescope.builtin').lsp_references, '[G]oto [R]eferences')
      map('n', 'gI', require('telescope.builtin').lsp_implementations, '[G]oto [I]mplementation')
      map('n', 'K', vim.lsp.buf.hover, 'Hover documentation')
      map('n', '<leader>rn', vim.lsp.buf.rename, '[R]e[n]ame')
      map({ 'n', 'x' }, '<leader>ca', vim.lsp.buf.code_action, '[C]ode [A]ction')

      if client and client.supports_method('textDocument/documentHighlight') then
        local highlight_augroup = vim.api.nvim_create_augroup('LspHighlights', { clear = false })
        vim.api.nvim_create_autocmd({ 'CursorHold', 'CursorHoldI' }, {
          buffer = bufnr,
          group = highlight_augroup,
          callback = vim.lsp.buf.document_highlight,
        })
        vim.api.nvim_create_autocmd({ 'CursorMoved', 'CursorMovedI' }, {
          buffer = bufnr,
          group = highlight_augroup,
          callback = vim.lsp.buf.clear_references,
        })
      end
    end

    local capabilities = require('cmp_nvim_lsp').default_capabilities()

    require('mason-lspconfig').setup({
      ensure_installed = {}, -- Add your LSPs here, e.g., { 'lua_ls', 'rust_analyzer' }
      handlers = {
        function(server_name)
          require('lspconfig')[server_name].setup({
            on_attach = on_attach,
            capabilities = capabilities,
          })
        end,
        ['lua_ls'] = function()
          require('lspconfig').lua_ls.setup({
            on_attach = on_attach,
            capabilities = capabilities,
            settings = {
              Lua = {
                diagnostics = { globals = { 'vim' } },
                workspace = { library = vim.api.nvim_get_runtime_file('', true) },
              },
            },
          })
        end,
      },
    })
  end,
}
