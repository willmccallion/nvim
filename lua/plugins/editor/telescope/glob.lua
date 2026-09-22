--- Glob filter parsing for the file and grep pickers.
--- Two spaces in a prompt separate the query from the rg globs after it:
--- `config  *.lua` or `TODO  src/** !*.test.ts`.

local M = {}

--- Splits a prompt at its first double space into the query and the rg globs after it.
---@param prompt string
---@return string query
---@return string[] globs
function M.split(prompt)
	local query, filter = prompt:match("^(.-)  (.*)$")
	if not query then
		return prompt, {}
	end
	return query, vim.split(filter, "%s+", { trimempty = true })
end

---@param globs string[]
---@return string[]
function M.rg_args(globs)
	local args = {}
	for _, glob in ipairs(globs) do
		vim.list_extend(args, { "--glob", glob })
	end
	return args
end

--- Compiles one glob into a predicate over a cwd-relative path, following rg:
--- a glob without a separator is matched against the file name alone.
---@param pattern string
---@return fun(path: string, name: string): boolean? nil when the glob does not parse
local function compile(pattern)
	local ok, lpeg = pcall(vim.glob.to_lpeg, pattern)
	if not ok then
		return nil
	end
	local on_name_only = not pattern:find("/", 1, true)
	return function(path, name)
		return lpeg:match(on_name_only and name or path) ~= nil
	end
end

local function any(predicates, path, name)
	for _, matches in ipairs(predicates) do
		if matches(path, name) then
			return true
		end
	end
	return false
end

--- The same filter rg applies to `--glob` arguments, for the listers that have
--- no glob support of their own: a leading "!" excludes, and with no including
--- glob every path that is not excluded is kept.
---@param globs string[]
---@return fun(path: string): boolean keep
function M.matcher(globs)
	local includes, excludes = {}, {}
	for _, glob in ipairs(globs) do
		local excluded = vim.startswith(glob, "!")
		-- A half-typed glob is not an error: it just filters nothing until it parses.
		local matches = compile(excluded and glob:sub(2) or glob)
		if matches then
			table.insert(excluded and excludes or includes, matches)
		end
	end

	return function(path)
		local name = vim.fs.basename(path)
		if any(excludes, path, name) then
			return false
		end
		return #includes == 0 or any(includes, path, name)
	end
end

return M
