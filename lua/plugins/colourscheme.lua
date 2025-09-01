vim.pack.add({"https://github.com/EdenEast/nightfox.nvim"})

require('nightfox').setup({
  options = {
    transparent = true,
  }
})

vim.cmd[[colorscheme terafox]]
