--- @module plugins.coding.autopairs
--- @brief Automatic bracket/quote pairing via nvim-autopairs.
--- Integrates with nvim-cmp to insert pairs on completion confirm.

vim.pack.add({ "https://github.com/windwp/nvim-autopairs" })

require("nvim-autopairs").setup()

local cmp_autopairs = require("nvim-autopairs.completion.cmp")
local cmp = require("cmp")
cmp.event:on("confirm_done", cmp_autopairs.on_confirm_done())
