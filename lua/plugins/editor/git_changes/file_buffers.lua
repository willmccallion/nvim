--- Finding the buffer of a file in the panel, and the read-only ones holding what
--- git has for files that are not on disk.

local M = {}

---@param name string
---@return integer?
function M.buffer_named(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf) == name then
			return buf
		end
	end
	return nil
end

---@param file ChangedFile
---@return string
function M.deleted_buffer_name(file)
	return "git-deleted://" .. file.path
end

---@param commit string
---@param file ChangedFile
---@return string
function M.commit_buffer_name(commit, file)
	return ("git-%s://%s"):format(commit, file.path)
end

--- A read-only buffer holding path as git has it at the first of sources (a
--- revision followed by ":", or ":" alone for the index) that has it.
---@param root string
---@param sources string[]
---@param path string
---@param name string the buffer's name, which also finds it again
---@return integer?
function M.git_file_buffer(root, sources, path, name)
	local existing = M.buffer_named(name)
	if existing then
		return existing
	end

	local result
	for _, source in ipairs(sources) do
		result = vim.system({ "git", "show", source .. path }, { cwd = root, text = true }):wait()
		if result.code == 0 then
			break
		end
	end
	if result.code ~= 0 then
		vim.notify("No earlier version of " .. path, vim.log.levels.WARN)
		return nil
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local lines = vim.split(result.stdout, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_name(buf, name)
	vim.bo[buf].filetype = vim.filetype.match({ filename = path, buf = buf }) or ""
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	return buf
end

--- A deleted file has nothing on disk, so it shows what was removed: with since,
--- its commit's copy; otherwise the staged copy if there is one, else the last commit's.
---@param root string
---@param since Since?
---@param file ChangedFile
---@return integer?
function M.deleted_file_buffer(root, since, file)
	local sources = since and { since.commit .. ":" } or { ":", "HEAD:" }
	return M.git_file_buffer(root, sources, file.path, M.deleted_buffer_name(file))
end

return M
