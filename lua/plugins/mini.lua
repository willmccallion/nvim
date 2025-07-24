-- lua/plugins/mini.lua
-- Uses parts of the mini.nvim suite

return {
  'echasnovski/mini.nvim',
  version = '*',
  config = function()
    require('mini.ai').setup({ n_lines = 500 })
    require('mini.surround').setup()
    require('mini.comment').setup()
    require('mini.pairs').setup()
    require('mini.trailspace').setup()
    require('mini.indentscope').setup()
  end,
}
