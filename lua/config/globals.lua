--- Leader keys and global flags.
--- Leader is Space. Local leader is "," so that a plugin mapping <localleader>
--- keys in its own buffer cannot shadow a leader domain; grug-far's buffer keys
--- are the ones that rely on it.

vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.g.have_nerd_font = true

-- Nothing here is a remote plugin, so these would only be looked for and warned about.
vim.g.loaded_node_provider = 0
vim.g.loaded_perl_provider = 0
vim.g.loaded_python3_provider = 0
vim.g.loaded_ruby_provider = 0
