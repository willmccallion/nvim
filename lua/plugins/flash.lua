return {
  'folke/flash.nvim',
  opts = {
     modes = {
       char = {
          keys = { "m", "F" },
       },
       search = {
         enabled = true,
       },
     },
     labels = "abcdefgh"
  },
   keys = {
     { "f", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash Jump" },
     { "S", mode = { "n", "x", "o" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
     { "r", mode = "o", function() require("flash").remote() end, desc = "Flash Remote" },
     { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Flash TS Search" },
   },
}
