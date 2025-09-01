vim.pack.add({
  'https://github.com/stevearc/oil.nvim',
  'https://github.com/stevearc/conform.nvim',
  'https://github.com/folke/flash.nvim',
  'https://github.com/lewis6991/gitsigns.nvim',
  'https://github.com/folke/todo-comments.nvim',
  'https://github.com/mbbill/undotree'
})

require('oil').setup({
  default_file_explorer = true,
  columns = {
    "icon",
  },
  keymaps = {
    ["g?"] = "actions.show_help",
    ["<CR>"] = "actions.select",
    ["<C-s>"] = "actions.select_vsplit",
    ["<C-h>"] = "actions.select_split",
    ["<C-t>"] = "actions.select_tab",
    ["<C-p>"] = "actions.preview",
    ["<C-c>"] = "actions.close",
    ["-"] = "actions.parent",
    ["_"] = "actions.open_cwd",
    ["`"] = "actions.cd",
    ["~"] = "actions.tcd",
    ["g."] = "actions.toggle_hidden",
  },
})

require('conform').setup({
  formatters_by_ft = {
    rust = { "rustfmt" },
    c = { "clang-format" },
    cpp = { "clang-format" },
  },
  format_on_save = {
    timeout_ms = 500,
    lsp_fallback = true,
  },
})

require('flash').setup({
})

vim.keymap.set({ "n", "v" }, "<leader>f", function()
  require("conform").format({ async = true, lsp_fallback = true })
end, { desc = "Format buffer" })

vim.keymap.set('n', '<leader>u', vim.cmd.UndotreeToggle, { desc = "Toggle [U]ndoTree" })
vim.keymap.set("n", "<leader>-", "<CMD>Oil<CR>", { desc = "Open parent directory with Oil" })
vim.keymap.set({ "n", "x", "o" }, "s", function() require("flash").jump() end, { desc = "Flash Jump" })
vim.keymap.set({ "n", "x", "o" }, "S", function() require("flash").treesitter() end, { desc = "Flash Treesitter" })
