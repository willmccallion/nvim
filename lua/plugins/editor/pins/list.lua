--- Pure operations on a project's pinned files: paths relative to the project root,
--- in the order their numbers are given. Performs no I/O.

local M = {}

---@param pins string[]
---@param path string relative to the project root
---@return integer? number the path is pinned as
function M.index_of(pins, path)
	for i, pin in ipairs(pins) do
		if pin == path then
			return i
		end
	end
	return nil
end

--- A path already pinned keeps its number.
---@param pins string[]
---@param path string relative to the project root
---@return string[] pins
---@return integer number the path is pinned as
function M.add(pins, path)
	local existing = M.index_of(pins, path)
	if existing then
		return pins, existing
	end
	local added = vim.list_extend({}, pins)
	table.insert(added, path)
	return added, #added
end

--- Reads the pin list back from the lines of the buffer it was edited in: blank
--- lines and repeats are dropped, and a path typed in full is made relative to the
--- root when it is inside it.
---@param lines string[]
---@param root string
---@return string[]
function M.from_lines(lines, root)
	local pins = {}
	for _, line in ipairs(lines) do
		local path = vim.trim(line)
		if path ~= "" then
			path = vim.fs.normalize(path)
			if vim.startswith(path, "/") then
				path = vim.fs.relpath(root, path) or path
			end
			if not M.index_of(pins, path) then
				table.insert(pins, path)
			end
		end
	end
	return pins
end

return M
