-- lua/plugins/undotree.lua
return {
  'mbbill/undotree',
  keys = {
    { '<leader>ut', ':UndotreeToggle<CR>:UndotreeFocus<CR>', desc = '[U]ndo[T]ree Toggle' },
    { '<leader>uh', ':UndotreeHide<CR>', desc = '[U]ndo[T]ree Hide' },
  },
  cmd = { "UndotreeToggle", "UndotreeHide", "UndotreeFocus" }, -- Load on command
}
