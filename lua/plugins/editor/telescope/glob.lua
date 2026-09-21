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

return M
