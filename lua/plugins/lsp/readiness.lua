--- Whether a language server has finished loading a project. rust-analyzer answers
--- lookups with nothing until then, which reads as "not found", so it reports when it is
--- ready and the lookups say that it is still loading instead.

local M = {}

---@type table<integer, true>
local loaded = {}

--- Handler for rust-analyzer's experimental/serverStatus notification.
---@param status { quiescent: boolean }
---@param ctx lsp.HandlerContext
function M.on_server_status(_, status, ctx)
	if status.quiescent and not loaded[ctx.client_id] then
		loaded[ctx.client_id] = true
		vim.cmd.redrawstatus({ bang = true })
	end
end

--- True while a server that reports its status hasn't finished its first load.
---@param client vim.lsp.Client
---@return boolean
function M.is_loading(client)
	local experimental = client.config.capabilities and client.config.capabilities.experimental
	return experimental ~= nil and experimental.serverStatusNotification == true and not loaded[client.id]
end

--- Wraps a lookup so it says a server is still loading rather than finding nothing.
---@param lookup fun()
---@return fun()
function M.when_loaded(lookup)
	return function()
		for _, client in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do
			if M.is_loading(client) then
				vim.notify(client.name .. " is still loading", vim.log.levels.WARN)
				return
			end
		end
		lookup()
	end
end

vim.api.nvim_create_autocmd("LspDetach", {
	desc = "Forget a stopped server's load, so a restart counts as loading again",
	group = vim.api.nvim_create_augroup("lsp-readiness", { clear = true }),
	callback = function(ev)
		loaded[ev.data.client_id] = nil
	end,
})

return M
