return {
  {
    "rose-pine/neovim",
    name = "rose-pine",
    priority = 1000,
    config = function()
      require("rose-pine").setup({
        disable_background = true,
        disable_float_background = true,
        disable_italics = false,
      })
    -- vim.cmd("colorscheme rose-pine")
    end,
  },

  {
    "folke/tokyonight.nvim",
    priority = 1000,
    config = function()
      require("tokyonight").setup({
        style = "storm",
        transparent = true,
      })
      -- vim.cmd("colorscheme tokyonight")
    end,
  },

  {
    "EdenEast/nightfox.nvim",
    priority = 1000,
    config = function()
      require("nightfox").setup({
        options = {
          transparent = true,
        }
      })
      vim.cmd("colorscheme terafox")
    end,
  }
}

