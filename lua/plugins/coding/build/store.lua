--- Per-project build command persistence.
--- Stores the selected and custom commands, and what was last debugged, for each
--- project root in a single JSON file under stdpath("data"), so nothing is written
--- into repositories.

local json_file = require("lib.json_file")

local M = {}

---@class build.ProjectState
---@field selected? string command run by <leader>mb
---@field custom string[] commands typed in by the user, most recent first
---@field run? string command run by <leader>mr
---@field run_custom string[] run commands typed in by the user, most recent first
---@field debug_program? string absolute path of the program last debugged
---@field debug_args? string its arguments as typed, empty for none

local path = vim.fs.joinpath(vim.fn.stdpath("data"), "build-commands.json")

---@param root string
---@return build.ProjectState
function M.load(root)
	local states = json_file.read(path) or {}
	local state = states[root] or {}
	return {
		selected = state.selected,
		custom = state.custom or {},
		run = state.run,
		run_custom = state.run_custom or {},
		debug_program = state.debug_program,
		debug_args = state.debug_args,
	}
end

--- Refuses to write if the existing file is corrupt, so it is never clobbered.
---@param root string
---@param state build.ProjectState
function M.save(root, state)
	local states = json_file.read(path)
	if not states then
		return
	end
	states[root] = state
	json_file.write(path, states)
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
