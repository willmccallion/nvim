return {
    'tpope/vim-fugitive',

    vim.keymap.set('n', '<leader>gd', function()
        vim.cmd('Git diff') -- Or 'Gvdiffsplit' for vertical
    end, { desc = '[G]it [D]iff current file (Fugitive)' })
}
