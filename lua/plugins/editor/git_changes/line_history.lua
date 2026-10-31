--- <leader>gh: the commits that changed the function under the cursor or the
--- selected lines, by git log -L.

local git = require("plugins.editor.git_changes.git")
local commits = require("plugins.editor.git_changes.commits")

local M = {}

--- The line of the committed file that a buffer line sits at, given the buffer's
--- changes from it. A changed line gives its old counterpart; a new line gives nil.
---@param hunks GitHunk[]
---@param line integer
---@return integer?
local function committed_line(hunks, line)
	local shift = 0
	for _, hunk in ipairs(hunks) do
		local added, removed = hunk.added, hunk.removed
		if added.count > 0 and line >= added.start and line < added.start + added.count then
			if removed.count == 0 then
				return nil
			end
			return removed.start + math.min(line - added.start, removed.count - 1)
		end
		-- A count of 0 puts start on the line before the gap.
		local next_added = added.start + math.max(added.count, 1)
		if line < next_added then
			break
		end
		shift = removed.start + math.max(removed.count, 1) - next_added
	end
	return line + shift
end

--- Where the buffer's lines first to last sit in the committed file, or nil when
--- all of them are new.
---@param hunks GitHunk[]
---@param first integer
---@param last integer
---@return integer? committed_first
---@return integer? committed_last
local function committed_range(hunks, first, last)
	local committed_first, committed_last
	for line = first, last do
		local committed = committed_line(hunks, line)
		if committed then
			committed_first = committed_first or committed
			committed_last = committed
		end
	end
	return committed_first, committed_last
end

--- The current file's path from root, or nil for a buffer that is no file in it.
---@param root string
---@return string?
local function path_in_repo(root)
	if vim.bo.buftype ~= "" then
		return nil
	end
	local real_path = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0))
	return real_path and vim.fs.relpath(root, real_path)
end

--- Lists the commits that changed lines first to last of the current file, each
--- previewed as its change to them. Picking one opens the panel on that commit,
--- at this file. git follows the lines from the last commit, so uncommitted edits
--- above them do not move the range onto other code.
---@param title string
---@param first integer
---@param last integer
---@param open_commit fun(root: string, commit: string, focus_path: string?)
local function pick_line_history(title, first, last, open_commit)
	local root = git.current_root()
	if not root then
		return
	end
	local path = path_in_repo(root)
	if not path then
		vim.notify("Git history needs a file in this repository", vim.log.levels.WARN)
		return
	end
	local committed_text = git.text_at(root, "HEAD", { path = path, status = "M" })
	local committed_first, committed_last = committed_range(git.hunks_against(committed_text, 0), first, last)
	if committed_text == "" or not committed_first then
		vim.notify("These lines have not been committed yet")
		return
	end

	local lines = ("%d,%d:%s"):format(committed_first, committed_last, path)
	-- The preview finds a commit by its place in the whole history, whoever's are listed.
	local place_in_history = {}
	for index, row in ipairs(commits.rows(root, nil, false, lines)) do
		place_in_history[row.commit] = index - 1
	end
	local function history(mine)
		return commits.rows(root, nil, mine, lines)
	end
	local function preview_change_to_lines(commit)
		return { "git", "-C", root, "log", "-L", lines, "--skip=" .. place_in_history[commit], "-n1" }
	end
	commits.pick("History of " .. title, history, preview_change_to_lines, function(picked)
		open_commit(root, picked.commit, path)
	end)
end

--- Lines first to last of the smallest function around the cursor, by the queries
--- ]f moves with, or nil outside any.
---@return integer? first
---@return integer? last
local function function_at_cursor()
	local parser = vim.treesitter.get_parser(0, nil, { error = false })
	local query = parser and vim.treesitter.query.get(parser:lang(), "textobjects")
	if not parser or not query then
		return nil
	end
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local first, last
	for id, node in query:iter_captures(parser:parse()[1]:root(), 0, row, row + 1) do
		local start_row, _, end_row, end_col = node:range()
		local final_row = end_col == 0 and end_row - 1 or end_row
		local around_cursor = start_row <= row and row <= final_row
		local smaller = not first or final_row - start_row < last - first
		if query.captures[id] == "function.outer" and around_cursor and smaller then
			first, last = start_row, final_row
		end
	end
	if not first then
		return nil
	end
	return first + 1, last + 1
end

---@param open_commit fun(root: string, commit: string, focus_path: string?)
function M.pick_function(open_commit)
	local first, last = function_at_cursor()
	if not first or not last then
		vim.notify("No function under the cursor; select lines to see their history", vim.log.levels.WARN)
		return
	end
	local signature = vim.trim(vim.api.nvim_buf_get_lines(0, first - 1, first, false)[1])
	pick_line_history(vim.fn.strcharpart(signature, 0, 40), first, last, open_commit)
end

---@param open_commit fun(root: string, commit: string, focus_path: string?)
function M.pick_selection(open_commit)
	local first, last = vim.fn.line("v"), vim.fn.line(".")
	if first > last then
		first, last = last, first
	end
	vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
	pick_line_history(("lines %d-%d"):format(first, last), first, last, open_commit)
end

return M
