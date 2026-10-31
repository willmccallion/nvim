--- Reading from git for the changed files panel and its pickers, and diffing a
--- buffer against what it returns.

local M = {}

--- The repository of the current file, or of the cwd for buffers that are not files.
---@return string?
local function repo_root()
	local start = vim.bo.buftype == "" and vim.fs.root(0, ".git") or vim.fn.getcwd()
	local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = start, text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	return vim.trim(result.stdout)
end

---@return string?
function M.current_root()
	local root = repo_root()
	if not root then
		vim.notify("Not inside a git repository", vim.log.levels.WARN)
	end
	return root
end

---@param root string
---@param args string[]
---@return string? # stdout, or nil after reporting the failure
function M.output(root, args)
	local result = vim.system(vim.list_extend({ "git" }, args), { cwd = root, text = true }):wait()
	if result.code ~= 0 then
		vim.notify(("git %s failed: %s"):format(args[1], vim.trim(result.stderr)), vim.log.levels.ERROR)
		return nil
	end
	return result.stdout
end

--- The file as rev has it, as one string; "" when rev does not have it, so
--- a file that is untracked or added since is all one added hunk.
---@param root string
---@param rev string
---@param file ChangedFile
---@return string
function M.text_at(root, rev, file)
	local spec = rev .. ":" .. (file.old_path or file.path)
	local committed = vim.system({ "git", "show", spec }, { cwd = root, text = true }):wait()
	return committed.code == 0 and committed.stdout or ""
end

--- The buffer's changes against old_text, staged or not, as the tint and ]h
--- visit both. Diffed here because gitsigns reports no hunks while it refreshes.
---@param old_text string
---@param buf integer
---@return GitHunk[]
function M.hunks_against(old_text, buf)
	local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
	local indices = vim.text.diff(old_text, current, { result_type = "indices" })
	---@cast indices integer[][]
	return vim.tbl_map(function(hunk)
		return { removed = { start = hunk[1], count = hunk[2] }, added = { start = hunk[3], count = hunk[4] } }
	end, indices)
end

return M
