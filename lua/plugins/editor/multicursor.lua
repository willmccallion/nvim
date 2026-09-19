--- Multi-cursor editing via vim-visual-multi.
--- Ctrl-n to select word, add cursors, and edit multiple locations at once.
--- Its <C-Up>/<C-Down> cursor maps are disabled so window resizing keeps them,
--- and its four-key <leader>vgS reselect is moved to <leader>vr.
--- Global VM commands live under <leader>v; keys used inside a session keep \\.

vim.g.VM_leader = { default = "<leader>v", visual = "<leader>v", buffer = "\\\\" }
vim.g.VM_maps = {
	["Add Cursor Down"] = "",
	["Add Cursor Up"] = "",
	["Reselect Last"] = "",
}

-- Load plugin/ now (not after init.lua) so its maps exist before the ones below replace them.
vim.pack.add({ "https://github.com/mg979/vim-visual-multi" }, { load = true })

--- Re-declared only to add descriptions, so <leader>sk can find them.
local described_maps = {
	{ "n", "<C-n>", "<Plug>(VM-Find-Under)", "Multi-cursor select word, then next match" },
	{ "x", "<C-n>", "<Plug>(VM-Find-Subword-Under)", "Multi-cursor select selection, then next match" },
	{ "n", "<leader>vA", "<Plug>(VM-Select-All)", "Multi-cursor select all matches of word" },
	{ "n", "<leader>v/", "<Plug>(VM-Start-Regex-Search)", "Multi-cursor select matches of a regex" },
	{ "n", "<leader>v\\", "<Plug>(VM-Add-Cursor-At-Pos)", "Multi-cursor add cursor at position" },
	{ "n", "<leader>vr", "<Plug>(VM-Reselect-Last)", "Multi-cursor reselect last session" },
	{ "x", "<leader>vA", "<Plug>(VM-Visual-All)", "Multi-cursor select all matches of selection" },
	{ "x", "<leader>va", "<Plug>(VM-Visual-Add)", "Multi-cursor add selection as region" },
	{ "x", "<leader>vc", "<Plug>(VM-Visual-Cursors)", "Multi-cursor add cursor on each selected line" },
	{ "x", "<leader>vf", "<Plug>(VM-Visual-Find)", "Multi-cursor find in selection" },
	{ "x", "<leader>v/", "<Plug>(VM-Visual-Regex)", "Multi-cursor regex search in selection" },
}
for _, m in ipairs(described_maps) do
	vim.keymap.set(m[1], m[2], m[3], { remap = true, desc = m[4] })
end
