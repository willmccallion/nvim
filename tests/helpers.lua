--- Assertions and small tools shared by the tests.

local M = {}

function M.assert_equal(actual, expected, what)
	if not vim.deep_equal(actual, expected) then
		error(("%s: expected %s, got %s"):format(what, vim.inspect(expected), vim.inspect(actual)), 2)
	end
end

function M.assert_contains(lines, wanted, what)
	for _, line in ipairs(lines) do
		if line:find(wanted, 1, true) then
			return
		end
	end
	error(("%s: no line has %q in %s"):format(what, wanted, vim.inspect(lines)), 2)
end

function M.refute_contains(lines, unwanted, what)
	for _, line in ipairs(lines) do
		if line:find(unwanted, 1, true) then
			error(("%s: %q should be absent from %s"):format(what, unwanted, vim.inspect(lines)), 2)
		end
	end
end

---@return string[] every message passed to vim.notify from now on
function M.capture_notifications()
	local seen = {}
	---@diagnostic disable-next-line: duplicate-set-field
	vim.notify = function(message)
		table.insert(seen, message)
	end
	return seen
end

---@param lhs string
---@param mode? string
function M.press(lhs, mode)
	vim.fn.maparg(vim.keycode(lhs), mode or "n", false, true).callback()
end

---@return string a new empty folder
function M.temp_dir()
	local dir = vim.fn.tempname()
	vim.fn.mkdir(dir, "p")
	return dir
end

return M
