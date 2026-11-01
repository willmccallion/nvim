--- Changing the commit gitsigns diffs against, one change at a time.

local gitsigns = require("gitsigns")

local M = {}

---@class BaseChange
---@field base string? nil for gitsigns' usual base, the index
---@field on_done fun()

---@type BaseChange[]
local base_changes = {}

--- change_base is asynchronous and sets the global base only once every attached
--- buffer is re-diffed, so a buffer attaching meanwhile gets the old base, and a
--- change started before another ends can be overtaken by it. Changes run one at
--- a time here, each calling its on_done once the base is in place.
local function run_next_base_change()
	local change = base_changes[1]
	if not change then
		return
	end
	gitsigns.change_base(change.base, true, function(err)
		vim.schedule(function()
			if err then
				vim.notify("gitsigns could not change its base: " .. tostring(err), vim.log.levels.ERROR)
			end
			table.remove(base_changes, 1)
			change.on_done()
			run_next_base_change()
		end)
	end)
end

---@param base string? nil for gitsigns' usual base
---@param on_done fun()
function M.set(base, on_done)
	if #base_changes == 0 and require("gitsigns.config").config.base == base then
		on_done()
		return
	end
	table.insert(base_changes, { base = base, on_done = on_done })
	if #base_changes == 1 then
		run_next_base_change()
	end
end

return M
