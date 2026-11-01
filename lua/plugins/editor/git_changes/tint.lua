--- The before and after of a change, drawn on a buffer: the old lines in red above
--- the new ones in green, the part that differs marked in both.

local tint_ns = vim.api.nvim_create_namespace("git-changes-tint")

--- Below this share of a line in common, two lines are different lines, not an edit.
local MIN_SIMILARITY = 0.5

--- Comparing every removed line with every added one runs on each keystroke in a review.
local MAX_COMPARISONS = 40000

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
function M.changed_span(old_line, line)
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

--- How much of two lines survives, from 0 for nothing to 1 when they are equal.
---@param old_line string
---@param line string
---@return number
local function similarity(old_line, line)
	local start, finish = M.changed_span(old_line, line)
	if not start then
		return 1
	end
	return (start + #line - finish) / math.max(#old_line, #line)
end

--- Which added line each removed line became, by resemblance, since a hunk's lines
--- need not line up: a removed comment would otherwise be compared with the code
--- below it, and everything on both would count as changed. Lines keep their order.
---@param removed string[]
---@param added string[]
---@return table<integer, integer> index in added, by index in removed
function M.pair_lines(removed, added)
	local paired = {}
	if #removed * #added > MAX_COMPARISONS then
		return paired
	end
	local first_free = 1
	for old_index, old_line in ipairs(removed) do
		local best, best_score = nil, MIN_SIMILARITY
		for index = first_free, #added do
			local score = similarity(old_line, added[index])
			if score > best_score then
				best, best_score = index, score
			end
		end
		if best then
			paired[old_index] = best
			first_free = best + 1
		end
	end
	return paired
end

--- The removed side of a hunk, as virtual lines with each line's changed part marked.
---@param removed string[]
---@param added string[]
---@param paired table<integer, integer>
---@param tabstop integer
---@return [string, string][][]
local function removed_virtual_lines(removed, added, paired, tabstop)
	local rows = {}
	for old_index, old_line in ipairs(removed) do
		local new_line = added[paired[old_index]]
		local start, _, old_finish = M.changed_span(old_line, new_line or "")
		if new_line and start then
			table.insert(
				rows,
				virtual_line({
					{ text = old_line:sub(1, start), group = "GitSignsDeleteVirtLn" },
					{ text = old_line:sub(start + 1, old_finish), group = "GitSignsDeleteVirtLnInLine" },
					{ text = old_line:sub(old_finish + 1), group = "GitSignsDeleteVirtLn" },
				}, tabstop)
			)
		else
			table.insert(rows, virtual_line({ { text = old_line, group = "GitSignsDeleteVirtLn" } }, tabstop))
		end
	end
	return rows
end

---@param buf integer
---@param hunk GitHunk
---@param rows [string, string][][]
local function show_removed(buf, hunk, rows)
	if #rows == 0 then
		return
	end
	-- A pure deletion's added.start is the line before it, 0 at the top.
	local above = hunk.added.count > 0 or hunk.added.start == 0
	local row = hunk.added.count > 0 and hunk.added.start - 1 or math.max(hunk.added.start - 1, 0)
	vim.api.nvim_buf_set_extmark(buf, tint_ns, row, 0, { virt_lines = rows, virt_lines_above = above })
end

---@param buf integer
---@param hunk GitHunk
---@param with_signs boolean
local function show_added(buf, hunk, with_signs)
	for offset = 0, hunk.added.count - 1 do
		vim.api.nvim_buf_set_extmark(buf, tint_ns, hunk.added.start + offset - 1, 0, {
			line_hl_group = "GitSignsAddPreview",
			sign_text = with_signs and "│" or nil,
			sign_hl_group = with_signs and "GitSignsAdd" or nil,
		})
	end
end

---@param buf integer
---@param hunk GitHunk
---@param removed string[]
---@param added string[]
---@param paired table<integer, integer>
local function mark_changed_parts(buf, hunk, removed, added, paired)
	for old_index, new_index in pairs(paired) do
		local start, finish = M.changed_span(removed[old_index], added[new_index])
		if start and finish > start then
			vim.api.nvim_buf_set_extmark(buf, tint_ns, hunk.added.start + new_index - 2, start, {
				end_col = finish,
				hl_group = "GitSignsAddInline",
			})
		end
	end
end

--- A hunk's removed and added lines.
---@param hunk GitHunk
---@param old_lines string[]
---@param lines string[] the buffer's
---@return string[] removed
---@return string[] added
local function lines_of(hunk, old_lines, lines)
	local removed = {}
	for offset = 0, hunk.removed.count - 1 do
		removed[offset + 1] = old_lines[hunk.removed.start + offset] or ""
	end
	return removed, vim.list_slice(lines, hunk.added.start, hunk.added.start + hunk.added.count - 1)
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
		local removed, added = lines_of(hunk, old_lines, lines)
		local paired = M.pair_lines(removed, added)
		show_removed(buf, hunk, removed_virtual_lines(removed, added, paired, tabstop))
		show_added(buf, hunk, with_signs)
		mark_changed_parts(buf, hunk, removed, added, paired)
	end
end

return M
