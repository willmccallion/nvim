--- Per-project build command persistence.
--- Stores the selected and custom commands for each project root in a single
--- JSON file under stdpath("data"), so nothing is written into repositories.

local M = {}

---@class build.ProjectState
---@field selected? string command run by <leader>mb
---@field custom string[] commands typed in by the user, most recent first
---@field run? string command run by <leader>mr
---@field run_custom string[] run commands typed in by the user, most recent first

local path = vim.fs.joinpath(vim.fn.stdpath("data"), "build-commands.json")

--- Returns nil, after reporting why, when the file exists but is not a JSON object.
---@return table<string, build.ProjectState>?
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
		vim.notify(
			("%s is not a JSON object (%s); fix or delete it"):format(path, tostring(decoded)),
			vim.log.levels.ERROR
		)
		return nil
	end
	return decoded
end

---@param root string
---@return build.ProjectState
function M.load(root)
	local states = read_all() or {}
	local state = states[root] or {}
	return {
		selected = state.selected,
		custom = state.custom or {},
		run = state.run,
		run_custom = state.run_custom or {},
	}
end

--- Refuses to write if the existing file is corrupt, so it is never clobbered.
---@param root string
---@param state build.ProjectState
function M.save(root, state)
	local states = read_all()
	if not states then
		return
	end
	states[root] = state

	-- Written beside the real file and renamed over it: a write cut short would
	-- otherwise leave the invalid JSON that read_all then refuses to touch.
	local tmp = path .. ".tmp"
	local file, open_err = io.open(tmp, "w")
	if not file then
		vim.notify(("Could not write %s: %s"):format(tmp, open_err), vim.log.levels.ERROR)
		return
	end
	file:write(vim.json.encode(states))
	file:close()

	local renamed, rename_err = vim.uv.fs_rename(tmp, path)
	if not renamed then
		vim.notify(("Could not replace %s: %s"):format(path, rename_err), vim.log.levels.ERROR)
	end
end

--- How many commands typed in by hand are kept per project.
local HISTORY_LIMIT = 10

--- Puts `cmd` at the front of `history`, dropping any duplicate and the oldest
--- entries past the limit.
---@param history string[]
---@param cmd string
---@return string[]
function M.remember(history, cmd)
	local kept = { cmd }
	for _, existing in ipairs(history) do
		if existing ~= cmd and #kept < HISTORY_LIMIT then
			table.insert(kept, existing)
		end
	end
	return kept
end

return M
