--- Every vim.notify message, LSP progress and vim.pack progress, via fidget.nvim.
--- Shows notifications, build status and LSP activity in the bottom right, in
--- normal text colour. Routing vim.notify here keeps messages out of the command
--- line, where long ones would stop for a "Press ENTER" prompt. Loaded before the
--- other plugins so their own startup messages arrive here too.
--- `:Fidget history` lists messages that have already faded.

vim.pack.add({ "https://github.com/j-hui/fidget.nvim" })

local fidget = require("fidget")

fidget.setup({
	notification = {
		override_vim_notify = true,
		-- Five seconds is tight for an error you have to act on.
		configs = {
			default = vim.tbl_extend("force", require("fidget.notification").default_config, { ttl = 8 }),
		},
		window = { normal_hl = "Normal" },
	},
})

--- Bold, in the colourscheme's DiagnosticOk green.
local function set_pack_complete_highlight()
	local ok = vim.api.nvim_get_hl(0, { name = "DiagnosticOk", link = false })
	vim.api.nvim_set_hl(0, "PackComplete", { fg = ok.fg, bold = true })
end

set_pack_complete_highlight()

local group = vim.api.nvim_create_augroup("pack-progress", { clear = true })

vim.api.nvim_create_autocmd("ColorScheme", {
	desc = "Recolour the vim.pack COMPLETE label for the new colourscheme",
	group = group,
	callback = set_pack_complete_highlight,
})

---@type table<string, { annote: string, style: string }>
local pack_progress_endings = {
	success = { annote = "COMPLETE", style = "PackComplete" },
	failed = { annote = "FAILED", style = "DiagnosticError" },
	cancel = { annote = "CANCELLED", style = "DiagnosticWarn" },
}

--- Each vim.pack step (downloading, applying, installing) keeps one line, which
--- counts up as "(k/n) - plugin" and then fades with its ending label.
---@param progress vim.event.progress.data
local function show_pack_progress(progress)
	local message = table.concat(progress.text)
	local ending = pack_progress_endings[progress.status]
	if ending then
		fidget.notify(message, ending.style, { group = "vim.pack", key = progress.id, annote = ending.annote, ttl = 0 })
	else
		fidget.notify(message, nil, { group = "vim.pack", key = progress.id, ttl = math.huge })
	end
end

vim.api.nvim_create_autocmd("Progress", {
	desc = "Show vim.pack progress in fidget",
	group = group,
	pattern = "vim.pack",
	callback = function(ev)
		show_pack_progress(ev.data)
	end,
})
