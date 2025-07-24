-- File: lua/your_module_name.lua (or wherever you keep this config)

local M = {}

-- Define the function locally so it's available for the keymap
local function lsp_symbol_search()
  -- Check if telescope.builtin is available
  local status_ok, builtin = pcall(require, 'telescope.builtin')
  if not status_ok then
    vim.notify("Telescope 'builtin' module not found. Is Telescope installed correctly?", vim.log.levels.ERROR)
    return
  end

  -- Check if any LSP clients are attached to the current buffer
  local clients = vim.lsp.get_active_clients({ bufnr = 0 }) -- bufnr = 0 means current buffer
  if vim.tbl_isempty(clients) then
    vim.notify("No active LSP client found for the current buffer.", vim.log.levels.WARN)
    return
  end

  -- Call the Telescope LSP workspace symbol search
  -- This searches symbols defined across your entire project/workspace.
  -- When you type 'string', it will fuzzy find symbols containing 'string'.
  print("Searching LSP workspace symbols...") -- Optional feedback
  builtin.lsp_workspace_symbols({
      -- You can customize the prompt title if you like
      prompt_title = "LSP Workspace Symbols",
      -- You can provide an initial query if desired, but usually you want to type it
      -- query = "initial search term",
  })
end

M.setup = function()
  -- Ensure Telescope is loaded before setting the keymap if needed,
  -- though usually it's loaded by the plugin manager earlier.

  vim.keymap.set("n", "<leader>ls", function()
    -- Call the function defined above
    lsp_symbol_search()
  end, { desc = "Search LSP Workspace Symbols" }) -- Updated description

  -- Optional: You can also create a user command
  vim.api.nvim_create_user_command('LspSymbolSearch', lsp_symbol_search, {
    desc = 'Search LSP Workspace Symbols using Telescope'
  })

  print("LSP Symbol Search keymap (<leader>ls) and command (:LspSymbolSearch) set up.") -- Feedback
end

return M

-- How to use this:
-- 1. Make sure this Lua module is required somewhere in your Neovim config (e.g., init.lua)
--    require('your_module_name').setup()
-- 2. Ensure you have 'nvim-telescope/telescope.nvim' installed.
-- 3. Ensure you have an LSP server configured (e.g., via nvim-lspconfig) and running for the file type you are editing.
-- 4. Open a file in your project where an LSP server is active.
-- 5. Press `<leader>ls` in Normal mode.
-- 6. The Telescope prompt will appear. Type your search query (e.g., "string", "http", "file_read").
-- 7. Telescope will fuzzy find matching symbols reported by the LSP server across your workspace.
