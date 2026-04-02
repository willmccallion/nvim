--- @module plugins.editor.surround
--- @brief Add/change/delete surrounding pairs via nvim-surround.
--- ys{motion}{char} to add, ds{char} to delete, cs{old}{new} to change.

vim.pack.add({ "https://github.com/kylechui/nvim-surround" })

require("nvim-surround").setup()
