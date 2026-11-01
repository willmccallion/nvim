--- The before and after of a change, drawn on a buffer: the old lines in red above
--- the new ones in green, the part that differs marked in both.

local tint_ns = vim.api.nvim_create_namespace("git-changes-tint")

local M = {}

---@param buf integer
function M.clear(buf)
	vim.api.nvim_buf_clear_namespace(buf, tint_ns, 0, -1)
end

--- Where two versions of a line differ: what is left between their longest
--- common start and longest common end, as 0-based byte columns in each.
---@param old_line string
---@param line string
---@return integer? start, nil when the lines are the same
---@return integer finish in line
---@return integer old_finish in old_line
local function changed_span(old_line, line)
	local start = 0
	while start < #line and start < #old_line and line:byte(start + 1) == old_line:byte(start + 1) do
		start = start + 1
	end
	if start == #line and start == #old_line then
		return nil, 0, 0
	end
	local line_end, old_end = #line, #old_line
	while line_end > start and old_end > start and line:byte(line_end) == old_line:byte(old_end) do
		line_end, old_end = line_end - 1, old_end - 1
	end
	return start, line_end, old_end
end

--- A removed line as virtual-line chunks, its changed part marked. Virtual lines
--- show a tab as a single cell, so tabs become the spaces the buffer would show.
---@param parts {text: string, group: string}[] the line in order
---@param tabstop integer
---@return [string, string][]
local function virtual_line(parts, tabstop)
	local chunks, column = {}, 0
	for _, part in ipairs(parts) do
		local pieces = vim.split(part.text, "\t", { plain = true })
		local text = {}
		for i, piece in ipairs(pieces) do
			table.insert(text, piece)
			column = column + vim.fn.strdisplaywidth(piece)
			if i < #pieces then
				local spaces = tabstop - column % tabstop
				table.insert(text, string.rep(" ", spaces))
				column = column + spaces
			end
		end
		table.insert(chunks, { table.concat(text), part.group })
	end
	-- Pads past the window's edge so the whole row is tinted, like a real line.
	table.insert(chunks, { string.rep(" ", vim.o.columns), "GitSignsDeleteVirtLn" })
	return chunks
end

--- Shows each change as a before and after: the removed lines in red as virtual
--- lines above the lines that replaced them, which are green, with the part of
--- each line that differs marked in both. Signs go in the gutter too unless
--- gitsigns already puts them there (with_signs false).
---@param buf integer
---@param hunks GitHunk[]
---@param old_lines string[]
---@param with_signs boolean
function M.show(buf, hunks, old_lines, with_signs)
	M.clear(buf)
	local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	local tabstop = vim.bo[buf].tabstop
	for _, hunk in ipairs(hunks) do
		local removed = {}
		for offset = 0, hunk.removed.count - 1 do
			local old_line = old_lines[hunk.removed.start + offset] or ""
			local new_line = offset < hunk.added.count and lines[hunk.added.start + offset] or nil
			local start, _, old_finish = changed_span(old_line, new_line or "")
			if new_line and start then
				table.insert(
					removed,
					virtual_line({
						{ text = old_line:sub(1, start), group = "GitSignsDeleteVirtLn" },
						{ text = old_line:sub(start + 1, old_finish), group = "GitSignsDeleteVirtLnInLine" },
						{ text = old_line:sub(old_finish + 1), group = "GitSignsDeleteVirtLn" },
					}, tabstop)
				)
			else
				table.insert(removed, virtual_line({ { text = old_line, group = "GitSignsDeleteVirtLn" } }, tabstop))
			end
		end
		if #removed > 0 then
			-- A pure deletion's added.start is the line before it, 0 at the top.
			local above = hunk.added.count > 0 or hunk.added.start == 0
			local row = hunk.added.count > 0 and hunk.added.start - 1 or math.max(hunk.added.start - 1, 0)
			vim.api.nvim_buf_set_extmark(buf, tint_ns, row, 0, { virt_lines = removed, virt_lines_above = above })
		end
		for offset = 0, hunk.added.count - 1 do
			local row = hunk.added.start + offset - 1
			vim.api.nvim_buf_set_extmark(buf, tint_ns, row, 0, {
				line_hl_group = "GitSignsAddPreview",
				sign_text = with_signs and "│" or nil,
				sign_hl_group = with_signs and "GitSignsAdd" or nil,
			})
			local old_line = offset < hunk.removed.count and old_lines[hunk.removed.start + offset]
			if old_line then
				local start, finish = changed_span(old_line, lines[row + 1])
				if start and finish > start then
					vim.api.nvim_buf_set_extmark(buf, tint_ns, row, start, {
						end_col = finish,
						hl_group = "GitSignsAddInline",
					})
				end
			end
		end
	end
end

return M
