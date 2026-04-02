--- @module plugins.lsp.fidget
--- @brief LSP progress notifications via fidget.nvim.
--- Shows non-intrusive status messages for LSP activity in the bottom right.

vim.pack.add({ "https://github.com/j-hui/fidget.nvim" })

require("fidget").setup()
