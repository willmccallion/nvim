--- Escaping for :substitute commands that must match and insert text literally.
--- Both helpers assume "/" as the delimiter.

local M = {}

--- Pattern that matches `text` exactly, regardless of regex metacharacters.
---@param text string
---@return string
function M.literal_pattern(text)
	local escaped = vim.fn.escape(text, "\\/"):gsub("\n", "\\n")
	return "\\V" .. escaped
end

--- Replacement that inserts `text` exactly, with no & or ~ expansion.
---@param text string
---@return string
function M.literal_replacement(text)
	local escaped = vim.fn.escape(text, "\\/&~"):gsub("\n", "\\r")
	return escaped
end

return M
