-- lua/plugins/lastplace.lua
return {
  'farmergreg/vim-lastplace',
  event = "BufReadPre", -- Load early to capture position
  config = function()
    -- No specific config needed, it works out of the box
  end,
}
