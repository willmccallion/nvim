--- Leader keys and global flags.
--- Leader is Space. Local leader is "," so that a plugin mapping <localleader>
--- keys in its own buffer cannot shadow a leader domain; grug-far's buffer keys
--- are the ones that rely on it.

vim.g.mapleader = " "
vim.g.maplocalleader = ","
vim.g.have_nerd_font = true
