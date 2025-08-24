return {
  'EdenEast/nightfox.nvim',
  priority = 1000,
  config = function()
    require('nightfox').setup({
      options = {
        transparent = true, -- Main transparency setting
        styles = {
          comments = 'italic',
          keywords = 'bold',
          types = 'italic,bold',
        },
      },
    })
    vim.cmd.colorscheme('terafox')

    -- Autocommand to make Telescope and other floating windows transparent
    vim.api.nvim_create_autocmd('ColorScheme', {
      pattern = '*',
      callback = function()
        local highlights = {
          'NormalFloat',
          'FloatBorder',
          'TelescopeNormal',
          'TelescopeBorder',
          'TelescopePromptNormal',
          'TelescopePromptBorder',
          'TelescopeResultsNormal',
          'TelescopeResultsBorder',
          'TelescopePreviewNormal',
          'TelescopePreviewBorder',
        }
        for _, hl in ipairs(highlights) do
          vim.api.nvim_set_hl(0, hl, { bg = 'none' })
        end
      end,
    })
  end,
}
