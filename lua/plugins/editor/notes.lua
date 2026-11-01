--- Notes: written here, read in Obsidian. render-markdown draws headings and tables,
--- snacks.image draws math and images through the terminal, and obsidian.nvim follows
--- links in the vault and opens the current note in the app, on the Mac when that is
--- where this nvim is being used from. obsidian.nvim is set up with the first vault file.

vim.pack.add({
	"https://github.com/obsidian-nvim/obsidian.nvim",
	"https://github.com/MeanderingProgrammer/render-markdown.nvim",
	"https://github.com/folke/snacks.nvim",
}, { load = false })

local on_first_require = require("lib.on_first_require")

local VAULT = vim.fs.normalize("~/notes")

--- tmux keeps the environment of the client that started a window, so ask it about
--- the session rather than trusting this process's own environment.
---@return boolean
local function at_the_mac()
	if not vim.env.TMUX then
		return vim.env.SSH_CONNECTION ~= nil
	end
	local result = vim.system({ "tmux", "show-environment", "SSH_CONNECTION" }, { text = true }):wait()
	return vim.startswith(result.stdout or "", "SSH_CONNECTION=")
end

---@param uri string
local function open_on_the_mac(uri)
	local command = { "ssh", "-o", "BatchMode=yes", "mac", "open", vim.fn.shellescape(uri) }
	vim.system(command, { text = true }, function(result)
		if result.code ~= 0 then
			vim.schedule(function()
				vim.notify("Opening on the Mac failed: " .. result.stderr, vim.log.levels.ERROR)
			end)
		end
	end)
end

---@param uri string
local function open_in_obsidian(uri)
	if at_the_mac() then
		open_on_the_mac(uri)
	else
		vim.ui.open(uri)
	end
end

local function setup_obsidian()
	vim.cmd.packadd("obsidian.nvim")
	require("obsidian").setup({
		legacy_commands = false,
		workspaces = { { name = "notes", path = VAULT } },
		-- On by default, and rewrites every note it saves.
		frontmatter = { enabled = false },
		-- Would make randomly named notes from a link that doesn't resolve yet.
		completion = { create_new = false },
		-- render-markdown draws the buffer.
		ui = { enable = false },
		footer = { enabled = false },
		open = { func = open_in_obsidian },
	})
end

vim.cmd.packadd("render-markdown.nvim")
vim.cmd.packadd("snacks.nvim")

require("render-markdown").setup({
	-- snacks.image draws math as the real formula.
	latex = { enabled = false },
	-- Padding counts math's source, not the formula drawn over it, so a table with math
	-- can't line up exactly: no top and bottom borders to show that.
	pipe_table = { style = "normal" },
})

--- Over SSH a file on this machine can't be read by the terminal, and tmux hides whether
--- this nvim is over SSH or can lose it on a later attach, so always send the image's data.
vim.env.SNACKS_SSH = "1"

require("snacks").setup({
	image = {
		enabled = vim.fn.executable("magick") == 1 and vim.fn.executable("pdflatex") == 1,
	},
})

vim.keymap.set("n", "<leader>nr", "<Cmd>RenderMarkdown buf_toggle<CR>", { desc = "Notes toggle drawn markdown" })

if vim.fn.isdirectory(VAULT) == 0 then
	return
end

on_first_require({ "obsidian" }, setup_obsidian)

vim.api.nvim_create_autocmd({ "BufReadPre", "BufNewFile" }, {
	desc = "Set up obsidian.nvim with the first file in the vault",
	group = vim.api.nvim_create_augroup("notes-vault", { clear = true }),
	pattern = VAULT .. "/*",
	once = true,
	callback = function()
		require("obsidian")
	end,
})

---@param command string the :Obsidian subcommand
local function obsidian(command)
	require("obsidian")
	vim.cmd.Obsidian(command)
end

vim.keymap.set("n", "<leader>no", function()
	vim.cmd.update()
	obsidian("open")
end, { desc = "Notes save and open this note in Obsidian" })

vim.keymap.set("n", "<leader>nb", function()
	obsidian("backlinks")
end, { desc = "Notes list what links to this note" })

vim.keymap.set("n", "<leader>nl", function()
	obsidian("links")
end, { desc = "Notes list this note's links" })
