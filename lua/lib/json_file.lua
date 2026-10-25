--- A JSON object kept in one file, for state remembered between sessions.
--- A corrupt file is reported and left alone rather than overwritten.

local M = {}

--- A missing or empty file reads as an empty object. Returns nil, after reporting
--- why, when the file exists but is not a JSON object.
---@param path string
---@return table?
function M.read(path)
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

--- Written beside the real file and renamed over it: a write cut short would
--- otherwise leave the invalid JSON that M.read then refuses to touch.
---@param path string
---@param value table
function M.write(path, value)
	local tmp = path .. ".tmp"
	local file, open_err = io.open(tmp, "w")
	if not file then
		vim.notify(("Could not write %s: %s"):format(tmp, open_err), vim.log.levels.ERROR)
		return
	end
	file:write(vim.json.encode(value))
	file:close()

	local renamed, rename_err = vim.uv.fs_rename(tmp, path)
	if not renamed then
		vim.notify(("Could not replace %s: %s"):format(path, rename_err), vim.log.levels.ERROR)
	end
end

return M
