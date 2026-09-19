--- @module plugins.coding.build.store
--- @brief Per-project build command persistence.
--- Stores the selected and custom commands for each project root in a single
--- JSON file under stdpath("data"), so nothing is written into repositories.

local M = {}

---@class build.ProjectState
---@field selected? string command run by <leader>mb
---@field custom string[] commands typed in by the user, most recent first

local path = vim.fs.joinpath(vim.fn.stdpath("data"), "build-commands.json")

---@return table<string, build.ProjectState>? states, string? err
local function read_all()
	local file = io.open(path, "r")
	if not file then
		return {}
	end
	local content = file:read("*a")
	file:close()
	if content == "" then
		return {}
	end
	local ok, decoded = pcall(vim.json.decode, content)
	if not ok or type(decoded) ~= "table" then
		return nil, ("%s is not valid JSON: %s"):format(path, decoded)
	end
	return decoded
end

---@param root string
---@return build.ProjectState
function M.load(root)
	local states, err = read_all()
	if not states then
		vim.notify(err, vim.log.levels.ERROR)
		return { custom = {} }
	end
	local state = states[root] or {}
	return { selected = state.selected, custom = state.custom or {} }
end

--- Refuses to write if the existing file is corrupt, so it is never clobbered.
---@param root string
---@param state build.ProjectState
function M.save(root, state)
	local states, err = read_all()
	if not states then
		vim.notify(err .. "; not saving", vim.log.levels.ERROR)
		return
	end
	states[root] = state
	local file, open_err = io.open(path, "w")
	if not file then
		vim.notify(("Could not write %s: %s"):format(path, open_err), vim.log.levels.ERROR)
		return
	end
	file:write(vim.json.encode(states))
	file:close()
end

return M
