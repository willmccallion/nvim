-- lua/plugins/conform.lua
-- Code formatting plugin

return {
  'stevearc/conform.nvim',
  event = { 'BufWritePre' }, -- Run formatting before saving
  cmd = { 'ConformInfo' },
  keys = {
    {
      -- Manually trigger format
      '<leader>ff', -- Changed keymap slightly to avoid conflict with telescope file search
      function()
        require('conform').format({ async = true, lsp_format = 'fallback' })
      end,
      mode = { 'n', 'v' }, -- Allow formatting in normal and visual mode
      desc = '[F]ormat buffer/selection',
    },
  },
  opts = {
    -- Define your formatters here
    formatters_by_ft = {
      lua = { 'stylua' },
      rust = { 'rustfmt' },
      -- python = { "isort", "black" },
      -- javascript = { { "prettierd", "prettier" } }, -- Use prettierd first, fallback to prettier
      -- typescript = { { "prettierd", "prettier" } },
      -- c = { "clang-format" },
      -- cpp = { "clang-format" },
      -- Add other filetypes and their formatters
      ['*'] = { 'trim_whitespace' }, -- Universal fallback
    },

    -- Configure format on save
    format_on_save = {
      timeout_ms = 500,      -- Stop formatting if it takes too long
      lsp_format = 'fallback', -- Use LSP formatting if no conform formatter is found
    },

    -- Optional: Customize notification behavior
    notify_on_error = true, -- Show notifications on errors
    -- notify_on_error = false, -- Disable notifications

    -- If you want to disable format-on-save for specific filetypes:
    -- format_on_save = function(bufnr)
    --   local disable_filetypes = { c = true, cpp = true } -- Example: disable for C/C++
    --   if disable_filetypes[vim.bo[bufnr].filetype] then
    --     return -- Return nothing to disable
    --   end
    --   -- Otherwise, return the standard options
    --   return { timeout_ms = 500, lsp_format = 'fallback' }
    -- end,
  },
}
