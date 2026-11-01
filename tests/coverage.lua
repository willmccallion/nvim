--- Which lines of lua/ the tests ran, counted with a debug hook.

local M = {}

---@type table<string, table<integer, true>>
local hits = {}

--- JIT-compiled code skips line hooks, so compilation stays off while counting.
---@param root string
function M.start(root)
	jit.off()
	jit.flush()
	local prefix = "@" .. vim.fs.joinpath(root, "lua") .. "/"
	debug.sethook(function(_, line)
		local source = debug.getinfo(2, "S").source
		if vim.startswith(source, prefix) then
			local lines = hits[source:sub(2)] or {}
			hits[source:sub(2)] = lines
			lines[line] = true
		end
	end, "l")
end

---@param dir string
function M.save(dir)
	debug.sethook()
	local rows = {}
	for path, lines in pairs(hits) do
		rows[#rows + 1] = path .. "\t" .. table.concat(vim.tbl_keys(lines), ",")
	end
	vim.fn.writefile(rows, vim.fs.joinpath(dir, tostring(vim.uv.os_getpid())))
end

--- Every line a function or the functions inside it can stop on.
---@param proto function
---@param lines table<integer, true>
local function add_executable_lines(proto, lines)
	local util = require("jit.util")
	local info = util.funcinfo(proto)
	for pc = 1, info.bytecodes - 1 do
		local line = util.funcinfo(proto, pc).currentline
		if line and line > 0 then
			lines[line] = true
		end
	end
	for index = 1, info.gcconsts do
		local constant = util.funck(proto, -index)
		if type(constant) == "proto" then
			add_executable_lines(constant, lines)
		end
	end
end

---@param path string
---@return table<integer, true>
local function executable_lines(path)
	local lines = {}
	add_executable_lines(assert(loadfile(path)), lines)
	return lines
end

---@param dir string
---@return table<string, table<integer, true>>
local function read_hits(dir)
	local merged = {}
	for _, file in ipairs(vim.fn.glob(dir .. "/*", false, true)) do
		for _, row in ipairs(vim.fn.readfile(file)) do
			local path, lines = row:match("^(.-)\t(.*)$")
			merged[path] = merged[path] or {}
			for line in lines:gmatch("%d+") do
				merged[path][tonumber(line)] = true
			end
		end
	end
	return merged
end

---@param root string
---@param dir string
function M.report(root, dir)
	local merged = read_hits(dir)
	local rows, total, covered = {}, 0, 0
	for _, path in ipairs(vim.fn.glob(root .. "/lua/**/*.lua", false, true)) do
		local executable, run = 0, 0
		for line in pairs(executable_lines(path)) do
			executable = executable + 1
			if merged[path] and merged[path][line] then
				run = run + 1
			end
		end
		total, covered = total + executable, covered + run
		rows[#rows + 1] = { path = vim.fs.relpath(root, path), run = run, executable = executable }
	end
	table.sort(rows, function(a, b)
		return a.run / math.max(a.executable, 1) < b.run / math.max(b.executable, 1)
	end)
	for _, row in ipairs(rows) do
		print(("%4d of %4d  %s"):format(row.run, row.executable, row.path))
	end
	print(("Lines the tests ran: %d of %d"):format(covered, total))
end

return M
