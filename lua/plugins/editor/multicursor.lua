--- @module plugins.editor.multicursor
--- @brief Multi-cursor editing via vim-visual-multi.
--- Ctrl-n to select word, add cursors, and edit multiple locations at once.
--- Its <C-Up>/<C-Down> cursor maps are disabled so window resizing keeps them.

vim.g.VM_maps = {
	["Add Cursor Down"] = "",
	["Add Cursor Up"] = "",
}

vim.pack.add({ "https://github.com/mg979/vim-visual-multi" })
