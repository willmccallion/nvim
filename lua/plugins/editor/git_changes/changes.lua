--- What differs: the changed files git reports, and the ranges of commits they are
--- listed over.

local git = require("plugins.editor.git_changes.git")

local M = {}

---@class ChangedFile
---@field path string relative to the repository root
---@field status string one git status letter, or "?" for untracked
---@field old_path string? where a renamed or copied file came from

---@class Since
---@field commit string the commit the changes are listed since
---@field summary string its short hash and subject, shown above the list
---@field label string? shown in the title in place of commit
---@field to ChangesEnd? what to list the changes up to; nil for the files as they are now

---@alias ChangesEnd {kind: "commit", commit: string}|{kind: "staged"}

--- The worktree letter wins over the index one, since it is what the buffer shows.
---@param index string
---@param worktree string
---@return string
local function status_letter(index, worktree)
	if index == "?" then
		return "?"
	end
	if worktree ~= " " then
		return worktree
	end
	return index
end

--- Root files come first, then each folder's files together, in path order.
---@param a ChangedFile
---@param b ChangedFile
---@return boolean
local function by_folder_then_name(a, b)
	local a_dir, b_dir = vim.fs.dirname(a.path), vim.fs.dirname(b.path)
	if a_dir ~= b_dir then
		if a_dir == "." or b_dir == "." then
			return a_dir == "."
		end
		return a_dir < b_dir
	end
	return a.path < b.path
end

--- Parses `git status --porcelain=v1 -z`, where a rename or copy record is
--- followed by an extra field holding the old path.
---@param output string
---@return ChangedFile[]
local function parse_porcelain(output)
	local files = {}
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local i = 1
	while i <= #fields do
		local record = fields[i]
		local index, worktree = record:sub(1, 1), record:sub(2, 2)
		local file = { path = record:sub(4), status = status_letter(index, worktree) }
		if index == "R" or index == "C" then
			file.old_path = fields[i + 1]
			i = i + 1
		end
		table.insert(files, file)
		i = i + 1
	end
	table.sort(files, by_folder_then_name)
	return files
end

--- Parses `git diff --name-status -z`, where each letter is its own field and a
--- rename or copy carries a similarity score and both its old and new paths.
---@param output string
---@return ChangedFile[]
local function parse_name_status(output)
	local files = {}
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local i = 1
	while i <= #fields do
		local letter = fields[i]:sub(1, 1)
		if letter == "R" or letter == "C" then
			table.insert(files, { status = letter, old_path = fields[i + 1], path = fields[i + 2] })
			i = i + 3
		else
			table.insert(files, { status = letter, path = fields[i + 1] })
			i = i + 2
		end
	end
	return files
end

---@param output string `git ls-files -z` paths
---@return ChangedFile[]
local function parse_untracked(output)
	return vim.tbl_map(function(path)
		return { status = "?", path = path }
	end, vim.split(output, "\0", { plain = true, trimempty = true }))
end

---@type ChangesEnd
M.STAGED = { kind = "staged" }

---@param commit string
---@return ChangesEnd
function M.commit_end(commit)
	return { kind = "commit", commit = commit }
end

---@param to ChangesEnd
---@return string
function M.end_name(to)
	return to.kind == "staged" and "staged" or to.commit
end

--- What `git show` takes before a path to read the file from there.
---@param to ChangesEnd
---@return string
function M.end_source(to)
	return to.kind == "staged" and ":" or to.commit .. ":"
end

--- What to say when since has nothing to show.
---@param since Since?
---@return string
function M.nothing_message(since)
	if not since then
		return "No changes"
	end
	if since.to and since.to.kind == "staged" then
		return "Nothing staged"
	end
	return "No changes since " .. since.summary
end

--- Whether the newer side is read-only copies from git, not the files as they are now.
---@param since Since?
---@return boolean
function M.shows_copies(since)
	return since ~= nil and since.to ~= nil
end

---@param since Since?
---@return string
function M.base_rev(since)
	return since and since.commit or "HEAD"
end

---@param since Since?
---@return string?
function M.title_of(since)
	if not since then
		return nil
	end
	if since.to then
		return ("%s → %s"):format(since.label or since.commit, M.end_name(since.to))
	end
	return "since " .. since.summary
end

--- Uncommitted changes from `git status`, or with since, everything that differs
--- from its commit: committed after it, staged, unstaged and untracked.
---@param root string
---@param since Since?
---@return ChangedFile[]?
function M.list(root, since)
	if not since then
		local status = git.output(root, { "status", "--porcelain=v1", "-z", "--untracked-files=all" })
		return status and parse_porcelain(status)
	end
	if since.to then
		local staged = since.to.kind == "staged"
		local range = staged and { "--cached", since.commit } or { since.commit, since.to.commit }
		local diff = git.output(root, vim.list_extend({ "diff", "--name-status", "-z", "-M" }, range))
		local files = diff and parse_name_status(diff)
		if files then
			table.sort(files, by_folder_then_name)
		end
		return files
	end
	local diff = git.output(root, { "diff", "--name-status", "-z", "-M", since.commit })
	local untracked = git.output(root, { "ls-files", "--others", "--exclude-standard", "-z" })
	if not diff or not untracked then
		return nil
	end
	local files = vim.list_extend(parse_name_status(diff), parse_untracked(untracked))
	table.sort(files, by_folder_then_name)
	return files
end

---@param root string
---@param commit string
---@return Since?
function M.since_of(root, commit)
	local summary = git.output(root, { "log", "-1", "--format=%h %s", commit })
	if not summary then
		return nil
	end
	local short = vim.split(summary, " ", { plain = true })[1]
	return { commit = short, summary = vim.trim(summary) }
end

--- The commit before commit, or nil for a repository's first commit.
---@param root string
---@param commit string
---@return string?
local function parent_of(root, commit)
	local result = vim.system(
		{ "git", "rev-parse", "--verify", "--quiet", "--short", commit .. "^" },
		{ cwd = root, text = true }
	):wait()
	return result.code == 0 and vim.trim(result.stdout) or nil
end

--- The range holding only what commit changed: from the commit before it, or for
--- a repository's first commit, from the empty tree.
---@param root string
---@param commit Since
---@return Since?
function M.own_changes(root, commit)
	local since
	local parent = parent_of(root, commit.commit)
	if parent then
		since = M.since_of(root, parent)
	else
		local empty_tree = git.output(root, { "hash-object", "-t", "tree", "/dev/null" })
		since = empty_tree and { commit = vim.trim(empty_tree), summary = "the empty tree", label = "empty" }
	end
	if since then
		since.to = M.commit_end(commit.commit)
	end
	return since
end

return M
