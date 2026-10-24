--- Neovim's default status line with the buffer's language servers added after the
--- diagnostics, so a server that never attached (or crashed) is visible at a glance.

local M = {}

--- Names of the language servers attached to the buffer, e.g. "clangd" or
--- "pyright ruff"; empty when there are none.
---@return string
function M.lsp_names()
	local names = {}
	for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
		table.insert(names, client.name)
	end
	table.sort(names)
	return table.concat(names, " ")
end

--- Inserted where the default shows the pending keys, just before the ruler.
local INSERT_BEFORE = "%(%k %)"
local LSP_ITEM = "%(%{v:lua.require'config.statusline'.lsp_names()} %)"

local default = vim.api.nvim_get_option_info2("statusline", {}).default
local at = default:find(INSERT_BEFORE, 1, true)
vim.o.statusline = at and (default:sub(1, at - 1) .. LSP_ITEM .. default:sub(at)) or (default .. " " .. LSP_ITEM)

vim.api.nvim_create_autocmd({ "LspAttach", "LspDetach" }, {
	desc = "Show language servers in the status line as they attach and detach",
	group = vim.api.nvim_create_augroup("statusline-lsp", { clear = true }),
	callback = function()
		vim.schedule(function()
			vim.cmd.redrawstatus({ bang = true })
		end)
	end,
})

return M
