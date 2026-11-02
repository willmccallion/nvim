--- Merge conflict markers in the buffer. ]n and [n step between conflicts, and <leader>go,
--- <leader>gt and <leader>ga replace the one under the cursor with our side, their side or
--- both. The sides are git's, so during a rebase "ours" is the branch being rebased onto.

local M = {}

---@class Conflict
---@field start integer line of the <<<<<<< marker
---@field base? integer line of the ||||||| marker, in the diff3 and zdiff3 styles
---@field separator integer line of the ======= marker
---@field finish integer line of the >>>>>>> marker

---@alias ConflictSide "ours"|"theirs"|"both"

local MARKER_LENGTH = 7

--- Longer runs are the markers of a conflict nested inside a merge base, not this one's.
---@param line string
---@param char string
---@return boolean
local function is_marker(line, char)
	return line:sub(1, MARKER_LENGTH) == char:rep(MARKER_LENGTH)
		and (#line == MARKER_LENGTH or line:sub(MARKER_LENGTH + 1, MARKER_LENGTH + 1) == " ")
end

---@param lines string[]
---@return Conflict[] in buffer order, leaving out any without all their markers
function M.parse(lines)
	local conflicts = {}
	local open
	for number, line in ipairs(lines) do
		if is_marker(line, "<") then
			open = { start = number }
		elseif open and not open.separator then
			if is_marker(line, "|") then
				open.base = number
			elseif is_marker(line, "=") then
				open.separator = number
			end
		elseif open and is_marker(line, ">") then
			open.finish = number
			table.insert(conflicts, open)
			open = nil
		end
	end
	return conflicts
end

---@param lines string[]
---@param conflict Conflict
---@param side ConflictSide
---@return string[] what the conflict becomes
function M.resolved(lines, conflict, side)
	local ours = vim.list_slice(lines, conflict.start + 1, (conflict.base or conflict.separator) - 1)
	local theirs = vim.list_slice(lines, conflict.separator + 1, conflict.finish - 1)
	if side == "ours" then
		return ours
	elseif side == "theirs" then
		return theirs
	end
	return vim.list_extend(ours, theirs)
end

---@param conflicts Conflict[]
---@param line integer
---@return Conflict?
function M.at(conflicts, line)
	for _, conflict in ipairs(conflicts) do
		if conflict.start <= line and line <= conflict.finish then
			return conflict
		end
	end
end

--- Wraps past the ends of the buffer, as a search does.
---@param conflicts Conflict[] at least one
---@param line integer
---@param forward boolean
---@return Conflict
function M.neighbour(conflicts, line, forward)
	if forward then
		for _, conflict in ipairs(conflicts) do
			if conflict.start > line then
				return conflict
			end
		end
		return conflicts[1]
	end
	for index = #conflicts, 1, -1 do
		if conflicts[index].start < line then
			return conflicts[index]
		end
	end
	return conflicts[#conflicts]
end

---@return string[]
local function buffer_lines()
	return vim.api.nvim_buf_get_lines(0, 0, -1, true)
end

---@param forward boolean
local function jump(forward)
	local conflicts = M.parse(buffer_lines())
	if #conflicts == 0 then
		vim.notify("No conflicts in this file", vim.log.levels.WARN)
		return
	end
	local line = vim.fn.line(".")
	for _ = 1, vim.v.count1 do
		line = M.neighbour(conflicts, line, forward).start
	end
	vim.cmd("normal! m'")
	vim.api.nvim_win_set_cursor(0, { line, 0 })
end

---@param side ConflictSide
local function keep(side)
	local lines = buffer_lines()
	local conflict = M.at(M.parse(lines), vim.fn.line("."))
	if not conflict then
		vim.notify("No conflict under the cursor", vim.log.levels.WARN)
		return
	end
	vim.api.nvim_buf_set_lines(0, conflict.start - 1, conflict.finish, true, M.resolved(lines, conflict, side))
	vim.api.nvim_win_set_cursor(0, { math.min(conflict.start, vim.api.nvim_buf_line_count(0)), 0 })
end

local next_conflict, previous_conflict = require("plugins.editor.motion_repeat").pair(function()
	jump(true)
end, function()
	jump(false)
end)

vim.keymap.set("n", "]n", next_conflict, { desc = "Git go to next merge conflict" })
vim.keymap.set("n", "[n", previous_conflict, { desc = "Git go to previous merge conflict" })
vim.keymap.set("n", "<leader>go", function()
	keep("ours")
end, { desc = "Git keep our side of the merge conflict" })
vim.keymap.set("n", "<leader>gt", function()
	keep("theirs")
end, { desc = "Git keep their side of the merge conflict" })
vim.keymap.set("n", "<leader>ga", function()
	keep("both")
end, { desc = "Git keep all of the merge conflict, both sides" })

return M
