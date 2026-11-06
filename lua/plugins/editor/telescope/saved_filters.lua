--- A picker's filters (the globs after two spaces), remembered per git project when it
--- closes, so a project's usual ones, like !*.test, come back with it. Clearing them
--- forgets them. A glob naming only a file name applies anywhere in the project; one with
--- a path is kept relative to the project root and given back relative to the folder
--- searched, or left out there when it points outside it. Kept in stdpath("state"), so
--- nothing is written into repositories.

local json_file = require("lib.json_file")

local STORE_PATH = vim.fs.joinpath(vim.fn.stdpath("state"), "picker_filters.json")

local M = {}

---@param glob string
---@return string negation "!" or ""
---@return string pattern
---@return boolean is_path whether it is matched against the path rather than the name
local function parts(glob)
	local negation, pattern = glob:match("^(!?)(.*)$")
	return negation, pattern, pattern:find("/", 1, true) ~= nil and not vim.startswith(pattern, "**")
end

--- A glob as typed in a folder, relative to the project root instead.
---@param glob string
---@param prefix string the folder's path in the project, ending in "/", or "" at its root
---@return string
function M.from_folder(glob, prefix)
	local negation, pattern, is_path = parts(glob)
	return is_path and negation .. prefix .. pattern or glob
end

--- A glob relative to the project root as typed in a folder, or nil when it points outside it.
---@param glob string
---@param prefix string the folder's path in the project, ending in "/", or "" at its root
---@return string?
function M.to_folder(glob, prefix)
	local negation, pattern, is_path = parts(glob)
	if not is_path then
		return glob
	end
	if not vim.startswith(pattern, prefix) then
		return nil
	end
	return negation .. pattern:sub(#prefix + 1)
end

--- The project a folder is in, and the folder's path in it as a prefix.
---@param folder string
---@return string root
---@return string prefix
local function project_of(folder)
	local root = vim.fs.root(folder, ".git") or folder
	local relative = vim.fs.relpath(root, folder)
	return root, (relative and relative ~= ".") and relative .. "/" or ""
end

---@param picker string which picker's filters, like "files" or "grep"
---@param folder string the folder searched
---@return string[]
function M.load(picker, folder)
	local root, prefix = project_of(folder)
	local saved = ((json_file.read(STORE_PATH) or {})[picker] or {})[root] or {}
	local globs = {}
	for _, glob in ipairs(saved) do
		local in_folder = M.to_folder(glob, prefix)
		if in_folder then
			table.insert(globs, in_folder)
		end
	end
	return globs
end

--- The project's saved globs that point outside the folder, which its picker never showed
--- and so must outlast a save from there, then the globs typed in it.
---@param saved string[] relative to the project root
---@param typed string[] as typed in the folder
---@param prefix string
---@return string[]
function M.merged(saved, typed, prefix)
	local globs = vim.tbl_filter(function(glob)
		return M.to_folder(glob, prefix) == nil
	end, saved)
	for _, glob in ipairs(typed) do
		table.insert(globs, M.from_folder(glob, prefix))
	end
	return globs
end

--- Refuses to write if the existing file is corrupt, so it is never clobbered.
---@param picker string
---@param folder string
---@param globs string[] as typed in folder
function M.save(picker, folder, globs)
	local all = json_file.read(STORE_PATH)
	if not all then
		return
	end
	local root, prefix = project_of(folder)
	all[picker] = all[picker] or {}
	local in_project = M.merged(all[picker][root] or {}, globs, prefix)
	if vim.deep_equal(all[picker][root] or {}, in_project) then
		return
	end
	all[picker][root] = #in_project > 0 and in_project or nil
	vim.fn.mkdir(vim.fs.dirname(STORE_PATH), "p")
	json_file.write(STORE_PATH, all)
end

return M
