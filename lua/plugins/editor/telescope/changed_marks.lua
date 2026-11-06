--- Marks the file picker's rows with git's status letter for files with uncommitted
--- changes (M changed, A added, ? untracked, U in conflict), so what you are working
--- on stands out; other rows get a blank mark to keep the names lined up.

local changes = require("plugins.editor.git_changes.changes")

local M = {}

---@type table<string, string>
local GROUPS = { A = "Added", ["?"] = "Added", U = "DiagnosticError" }

--- The status letter of each changed file under folder, by its path from there.
---@param folder string
---@return table<string, string>
function M.letters(folder)
	local root = vim.fs.root(folder, ".git")
	if not root then
		return {}
	end
	local letters = {}
	for _, file in ipairs(changes.list(root, nil) or {}) do
		local path = vim.fs.relpath(folder, vim.fs.joinpath(root, file.path))
		if path then
			letters[path] = file.status
		end
	end
	return letters
end

--- An entry maker whose rows start with their file's letter, coloured, or a blank.
---@param make_entry fun(line: string): table?
---@param letters table<string, string> from M.letters
---@return fun(line: string): table?
function M.marked(make_entry, letters)
	local merge_styles = require("telescope.utils").merge_styles
	return function(line)
		local entry = make_entry(line)
		if not entry then
			return entry
		end
		local display = entry.display
		entry.display = function(shown)
			local text, style = display(shown)
			local letter = letters[shown.value]
			local mark = letter and { { { 0, 1 }, GROUPS[letter] or "Changed" } } or {}
			return (letter or " ") .. " " .. text, merge_styles(mark, style or {}, 2)
		end
		return entry
	end
end

return M
