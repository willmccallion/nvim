--- @module plugins.editor.comment
--- @brief Toggle comments via Comment.nvim.
--- gcc for line comments, gbc for block comments.

vim.pack.add({ "https://github.com/numToStr/Comment.nvim" })

require("Comment").setup()
