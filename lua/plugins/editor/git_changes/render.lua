--- The panel's text: a file list as lines and highlights, and the width to show them.

local devicons = require("nvim-web-devicons")

local M = {}

local MIN_WIDTH = 25
local MAX_WIDTH = 50

local STATUS_HIGHLIGHTS = {
	["?"] = "GitSignsAdd",
	A = "GitSignsAdd",
	D = "GitSignsDelete",
	U = "DiagnosticError",
}

---@class PanelMark
---@field row integer 0-based
---@field col_start integer byte offset
---@field col_end integer byte offset
---@field group string

---@class PanelContent
---@field lines string[]
---@field marks PanelMark[]
---@field files_by_line table<integer, ChangedFile> keyed by 1-based line number

---@param files ChangedFile[]
---@param title string? a line above the list
---@return PanelContent
function M.content(files, title)
	local content = { lines = {}, marks = {}, files_by_line = {} }
	local notes = {}
	if title then
		table.insert(notes, title)
	end
	if #files == 0 then
		table.insert(notes, "No changes")
	end
	for _, note in ipairs(notes) do
		table.insert(content.lines, note)
		table.insert(content.marks, { row = #content.lines - 1, col_start = 0, col_end = #note, group = "Comment" })
	end
	if #files == 0 then
		return content
	end

	local current_dir = "."
	for _, file in ipairs(files) do
		local dir = vim.fs.dirname(file.path)
		if dir ~= current_dir and dir ~= "." then
			local header = dir .. "/"
			table.insert(content.lines, header)
			table.insert(
				content.marks,
				{ row = #content.lines - 1, col_start = 0, col_end = #header, group = "Directory" }
			)
		end
		current_dir = dir

		local name = vim.fs.basename(file.path)
		local icon, icon_group = devicons.get_icon(name, nil, { default = true })
		local indent = dir == "." and "" or "  "
		local status_col = #indent
		local icon_col = status_col + #file.status + 1
		table.insert(content.lines, ("%s%s %s %s"):format(indent, file.status, icon, name))

		local row = #content.lines - 1
		local status_group = STATUS_HIGHLIGHTS[file.status] or "GitSignsChange"
		table.insert(content.marks, { row = row, col_start = status_col, col_end = icon_col - 1, group = status_group })
		table.insert(content.marks, { row = row, col_start = icon_col, col_end = icon_col + #icon, group = icon_group })
		content.files_by_line[#content.lines] = file
	end
	return content
end

---@param content PanelContent
---@return integer
function M.width(content)
	local widest = 0
	for _, line in ipairs(content.lines) do
		widest = math.max(widest, vim.fn.strdisplaywidth(line))
	end
	return math.min(math.max(widest + 2, MIN_WIDTH), MAX_WIDTH)
end

---@param files_by_line table<integer, ChangedFile>
---@param path string?
---@return integer?
function M.line_of(files_by_line, path)
	local first_file_line = nil
	for line, file in pairs(files_by_line) do
		if file.path == path then
			return line
		end
		first_file_line = math.min(first_file_line or line, line)
	end
	return first_file_line
end

return M
