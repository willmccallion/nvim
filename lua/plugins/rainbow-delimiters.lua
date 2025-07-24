-- lua/plugins/rainbow-delimiters.lua
return {
  'HiPhish/rainbow-delimiters.nvim',
  event = "BufReadPost", -- Load after buffer is read
  config = function()
    -- This approach applies the settings at config time.
    -- It relies on the plugin having set up the highlight groups first.
    local gray_color = '#555555' -- Use a single subtle color

    -- Get the default highlight groups from the plugin (optional, for reference)
    -- local rainbow_delimiters = require('rainbow-delimiters')

    -- Override all delimiter colors
    vim.api.nvim_set_hl(0, 'RainbowDelimiterRed', { fg = gray_color })
    vim.api.nvim_set_hl(0, 'RainbowDelimiterYellow', { fg = gray_color })
    vim.api.nvim_set_hl(0, 'RainbowDelimiterGreen', { fg = gray_color })
    vim.api.nvim_set_hl(0, 'RainbowDelimiterCyan', { fg = gray_color })
    vim.api.nvim_set_hl(0, 'RainbowDelimiterBlue', { fg = gray_color })
    vim.api.nvim_set_hl(0, 'RainbowDelimiterViolet', { fg = gray_color })
    vim.api.nvim_set_hl(0, 'RainbowDelimiterOrange', { fg = gray_color }) -- Newer versions might have this
    -- Add any other groups the plugin defines if needed

    -- Optional: If highlights don't apply correctly, try scheduling them
    -- vim.schedule(function()
    --   vim.api.nvim_set_hl(0, 'RainbowDelimiterRed', { fg = gray_color })
    --   -- ... set other highlights ...
    -- end)
  end,
}

-- Note: The original `vim.cmd` approach is less robust. Using `nvim_set_hl` is preferred.
-- Ensure the highlight group names ('RainbowDelimiterRed', etc.) match those defined by the plugin.
