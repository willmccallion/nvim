--- The file picker's filters (the globs after two spaces), remembered per folder when
--- it closes, so a project's usual ones, like !*.test, come back with it. Clearing them
--- forgets them. Kept in stdpath("state"), so nothing is written into repositories.

local json_file = require("lib.json_file")

local STORE_PATH = vim.fs.joinpath(vim.fn.stdpath("state"), "file_filters.json")

local M = {}

---@param folder string
---@return string[]
function M.load(folder)
	return (json_file.read(STORE_PATH) or {})[folder] or {}
end

--- Refuses to write if the existing file is corrupt, so it is never clobbered.
---@param folder string
---@param globs string[]
function M.save(folder, globs)
	local all = json_file.read(STORE_PATH)
	if not all or vim.deep_equal(all[folder] or {}, globs) then
		return
	end
	all[folder] = #globs > 0 and globs or nil
	vim.fn.mkdir(vim.fs.dirname(STORE_PATH), "p")
	json_file.write(STORE_PATH, all)
end

return M
