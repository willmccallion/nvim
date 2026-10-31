--- Changed files panel. <leader>gd lists the repository's uncommitted changes in
--- a split on the left, grouped by folder, and <leader>gD everything changed since
--- a commit picked from the log, up to the files as they are now or to a later
--- commit picked next. The file under the cursor previews on the right at its
--- first change, folded down to the changes and the lines around them. Each change
--- shows as a before and after: the old lines in red above the new ones in green,
--- the part that differs marked in both; <CR> moves into it. Files as they are now
--- are the real ones, kept up to date as you edit; a later commit's are read-only
--- copies. The panel stays open, and <leader>gd closes it, returns to the file it
--- was opened from and puts the folds, colours and gitsigns' base back.
--- <leader>gh lists the commits that changed the function under the cursor, or the
--- selected lines, and opens the panel on the one picked.
--- :GitChanges [older [newer]] opens the same from the command line (g diff does),
--- :GitChanges --commit [commit] what one commit changed, picked from the log when
--- not given, and :GitChanges --cached [commit] what is staged against commit, HEAD
--- by default.

local gitsigns = require("gitsigns")
local devicons = require("nvim-web-devicons")
local folds = require("plugins.editor.git_changes.folds")

local MIN_WIDTH = 25
local MAX_WIDTH = 50

local STATUS_HIGHLIGHTS = {
	["?"] = "GitSignsAdd",
	A = "GitSignsAdd",
	D = "GitSignsDelete",
	U = "DiagnosticError",
}

local ns = vim.api.nvim_create_namespace("git-changes")
local tint_ns = vim.api.nvim_create_namespace("git-changes-tint")
local edits_group = vim.api.nvim_create_augroup("git-changes-edits", { clear = true })

---@class ChangedFile
---@field path string relative to the repository root
---@field status string one git status letter, or "?" for untracked
---@field old_path string? where a renamed or copied file came from

---@class Since
---@field commit string the commit the changes are listed since
---@field summary string its short hash and subject, shown above the list
---@field label string? shown in the title in place of commit
---@field to Since? a later commit to list the changes up to; nil for the files as they are now
---@field index boolean? in a to, it stands for the staged files instead of a commit

---@class PanelMark
---@field row integer 0-based
---@field col_start integer byte offset
---@field col_end integer byte offset
---@field group string

---@class PanelContent
---@field lines string[]
---@field marks PanelMark[]
---@field files_by_line table<integer, ChangedFile> keyed by 1-based line number

---@class Panel
---@field buf integer
---@field win integer
---@field root string
---@field width integer
---@field target_win integer the window files open in
---@field files_by_line table<integer, ChangedFile>
---@field preview_buf integer? a buffer the preview loaded, closed once superseded
---@field origin_buf integer the buffer the panel was opened from, shown again on close
---@field origin_view vim.fn.winsaveview.ret its view at the time
---@field since Since? nil for the uncommitted changes
---@field ready boolean false until gitsigns diffs against the panel's base, so no preview attaches early
---@field bases table<integer, BaseText> by buffer, each real file the preview tinted, to tint again on edits

---@class BaseText
---@field text string the file as the panel's base commit has it
---@field lines string[] the same, split into lines

---@class BaseChange
---@field base string? nil for gitsigns' usual base, the index
---@field on_done fun()

---@type Panel?
local panel = nil

---@type BaseChange[]
local base_changes = {}

--- The worktree letter wins over the index one, since it is what the buffer shows.
---@param index string
---@param worktree string
---@return string
local function status_letter(index, worktree)
	if index == "?" then
		return "?"
	end
	if worktree ~= " " then
		return worktree
	end
	return index
end

--- Root files come first, then each folder's files together, in path order.
---@param a ChangedFile
---@param b ChangedFile
---@return boolean
local function by_folder_then_name(a, b)
	local a_dir, b_dir = vim.fs.dirname(a.path), vim.fs.dirname(b.path)
	if a_dir ~= b_dir then
		if a_dir == "." or b_dir == "." then
			return a_dir == "."
		end
		return a_dir < b_dir
	end
	return a.path < b.path
end

--- Parses `git status --porcelain=v1 -z`, where a rename or copy record is
--- followed by an extra field holding the old path.
---@param output string
---@return ChangedFile[]
local function parse_porcelain(output)
	local files = {}
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local i = 1
	while i <= #fields do
		local record = fields[i]
		local index, worktree = record:sub(1, 1), record:sub(2, 2)
		local file = { path = record:sub(4), status = status_letter(index, worktree) }
		if index == "R" or index == "C" then
			file.old_path = fields[i + 1]
			i = i + 1
		end
		table.insert(files, file)
		i = i + 1
	end
	table.sort(files, by_folder_then_name)
	return files
end

--- Parses `git diff --name-status -z`, where each letter is its own field and a
--- rename or copy carries a similarity score and both its old and new paths.
---@param output string
---@return ChangedFile[]
local function parse_name_status(output)
	local files = {}
	local fields = vim.split(output, "\0", { plain = true, trimempty = true })
	local i = 1
	while i <= #fields do
		local letter = fields[i]:sub(1, 1)
		if letter == "R" or letter == "C" then
			table.insert(files, { status = letter, old_path = fields[i + 1], path = fields[i + 2] })
			i = i + 3
		else
			table.insert(files, { status = letter, path = fields[i + 1] })
			i = i + 2
		end
	end
	return files
end

---@param output string `git ls-files -z` paths
---@return ChangedFile[]
local function parse_untracked(output)
	return vim.tbl_map(function(path)
		return { status = "?", path = path }
	end, vim.split(output, "\0", { plain = true, trimempty = true }))
end

---@param files ChangedFile[]
---@param title string? a line above the list
---@return PanelContent
local function render(files, title)
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
local function panel_width(content)
	local widest = 0
	for _, line in ipairs(content.lines) do
		widest = math.max(widest, vim.fn.strdisplaywidth(line))
	end
	return math.min(math.max(widest + 2, MIN_WIDTH), MAX_WIDTH)
end

--- change_base is asynchronous and sets the global base only once every attached
--- buffer is re-diffed, so a buffer attaching meanwhile gets the old base, and a
--- change started before another ends can be overtaken by it. Changes run one at
--- a time here, each calling its on_done once the base is in place.
local function run_next_base_change()
	local change = base_changes[1]
	if not change then
		return
	end
	gitsigns.change_base(change.base, true, function(err)
		vim.schedule(function()
			if err then
				vim.notify("gitsigns could not change its base: " .. tostring(err), vim.log.levels.ERROR)
			end
			table.remove(base_changes, 1)
			change.on_done()
			run_next_base_change()
		end)
	end)
end

---@param base string? nil for gitsigns' usual base
---@param on_done fun()
local function set_gitsigns_base(base, on_done)
	if #base_changes == 0 and require("gitsigns.config").config.base == base then
		on_done()
		return
	end
	table.insert(base_changes, { base = base, on_done = on_done })
	if #base_changes == 1 then
		run_next_base_change()
	end
end

---@param since Since?
---@return string
local function base_rev(since)
	return since and since.commit or "HEAD"
end

---@param since Since?
---@return string?
local function title_of(since)
	if not since then
		return nil
	end
	if since.to then
		return ("%s → %s"):format(since.label or since.commit, since.to.commit)
	end
	return "since " .. since.summary
end

--- The repository of the current file, or of the cwd for buffers that are not files.
---@return string?
local function repo_root()
	local start = vim.bo.buftype == "" and vim.fs.root(0, ".git") or vim.fn.getcwd()
	local result = vim.system({ "git", "rev-parse", "--show-toplevel" }, { cwd = start, text = true }):wait()
	if result.code ~= 0 then
		return nil
	end
	return vim.trim(result.stdout)
end

---@param root string
---@param args string[]
---@return string? # stdout, or nil after reporting the failure
local function git_output(root, args)
	local result = vim.system(vim.list_extend({ "git" }, args), { cwd = root, text = true }):wait()
	if result.code ~= 0 then
		vim.notify(("git %s failed: %s"):format(args[1], vim.trim(result.stderr)), vim.log.levels.ERROR)
		return nil
	end
	return result.stdout
end

--- Uncommitted changes from `git status`, or with since, everything that differs
--- from its commit: committed after it, staged, unstaged and untracked.
---@param root string
---@param since Since?
---@return ChangedFile[]?
local function changed_files(root, since)
	if not since then
		local status = git_output(root, { "status", "--porcelain=v1", "-z", "--untracked-files=all" })
		return status and parse_porcelain(status)
	end
	if since.to then
		local range = since.to.index and { "--cached", since.commit } or { since.commit, since.to.commit }
		local diff = git_output(root, vim.list_extend({ "diff", "--name-status", "-z", "-M" }, range))
		local files = diff and parse_name_status(diff)
		if files then
			table.sort(files, by_folder_then_name)
		end
		return files
	end
	local diff = git_output(root, { "diff", "--name-status", "-z", "-M", since.commit })
	local untracked = git_output(root, { "ls-files", "--others", "--exclude-standard", "-z" })
	if not diff or not untracked then
		return nil
	end
	local files = vim.list_extend(parse_name_status(diff), parse_untracked(untracked))
	table.sort(files, by_folder_then_name)
	return files
end

---@param files_by_line table<integer, ChangedFile>
---@param path string?
---@return integer?
local function line_of(files_by_line, path)
	local first_file_line = nil
	for line, file in pairs(files_by_line) do
		if file.path == path then
			return line
		end
		first_file_line = math.min(first_file_line or line, line)
	end
	return first_file_line
end

---@param files ChangedFile[]
local function draw(files)
	assert(panel, "draw needs an open panel")
	local cursor_line = vim.api.nvim_win_get_cursor(panel.win)[1]
	local file_under_cursor = panel.files_by_line[cursor_line]

	local content = render(files, title_of(panel.since))
	vim.bo[panel.buf].modifiable = true
	vim.api.nvim_buf_set_lines(panel.buf, 0, -1, false, content.lines)
	vim.bo[panel.buf].modifiable = false
	vim.api.nvim_buf_clear_namespace(panel.buf, ns, 0, -1)
	for _, mark in ipairs(content.marks) do
		vim.api.nvim_buf_set_extmark(panel.buf, ns, mark.row, mark.col_start, {
			end_col = mark.col_end,
			hl_group = mark.group,
		})
	end
	panel.files_by_line = content.files_by_line

	local line = line_of(content.files_by_line, file_under_cursor and file_under_cursor.path) or 1
	vim.api.nvim_win_set_cursor(panel.win, { line, 0 })
end

local function refresh()
	if not panel then
		return
	end
	local files = changed_files(panel.root, panel.since)
	if files then
		draw(files)
	end
end

---@param name string
---@return integer?
local function buffer_named(name)
	for _, buf in ipairs(vim.api.nvim_list_bufs()) do
		if vim.api.nvim_buf_get_name(buf) == name then
			return buf
		end
	end
	return nil
end

---@param file ChangedFile
---@return string
local function deleted_buffer_name(file)
	return "git-deleted://" .. file.path
end

---@param commit string
---@param file ChangedFile
---@return string
local function commit_buffer_name(commit, file)
	return ("git-%s://%s"):format(commit, file.path)
end

--- A read-only buffer holding path as git has it at the first of sources (a
--- revision followed by ":", or ":" alone for the index) that has it.
---@param root string
---@param sources string[]
---@param path string
---@param name string the buffer's name, which also finds it again
---@return integer?
local function git_file_buffer(root, sources, path, name)
	local existing = buffer_named(name)
	if existing then
		return existing
	end

	local result
	for _, source in ipairs(sources) do
		result = vim.system({ "git", "show", source .. path }, { cwd = root, text = true }):wait()
		if result.code == 0 then
			break
		end
	end
	if result.code ~= 0 then
		vim.notify("No earlier version of " .. path, vim.log.levels.WARN)
		return nil
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local lines = vim.split(result.stdout, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_name(buf, name)
	vim.bo[buf].filetype = vim.filetype.match({ filename = path, buf = buf }) or ""
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	return buf
end

--- A deleted file has nothing on disk, so it shows what was removed: with since,
--- its commit's copy; otherwise the staged copy if there is one, else the last commit's.
---@param root string
---@param since Since?
---@param file ChangedFile
---@return integer?
local function deleted_file_buffer(root, since, file)
	local sources = since and { since.commit .. ":" } or { ":", "HEAD:" }
	return git_file_buffer(root, sources, file.path, deleted_buffer_name(file))
end

--- The window files open in: the one the panel was opened from while it lasts,
--- then any other window in the tabpage, then a new split on the right.
---@return integer
local function target_window()
	assert(panel, "target_window needs an open panel")
	local tabpage_wins = vim.api.nvim_tabpage_list_wins(0)
	if
		vim.api.nvim_win_is_valid(panel.target_win)
		and panel.target_win ~= panel.win
		and vim.list_contains(tabpage_wins, panel.target_win)
	then
		return panel.target_win
	end
	for _, win in ipairs(tabpage_wins) do
		if win ~= panel.win and vim.api.nvim_win_get_config(win).relative == "" then
			return win
		end
	end
	local placeholder = vim.api.nvim_create_buf(false, true)
	vim.bo[placeholder].bufhidden = "wipe"
	local win = vim.api.nvim_open_win(placeholder, false, { split = "right", win = -1 })
	vim.api.nvim_win_set_config(panel.win, { width = panel.width })
	return win
end

--- The file as rev has it, as one string; "" when rev does not have it, so
--- a file that is untracked or added since is all one added hunk.
---@param root string
---@param rev string
---@param file ChangedFile
---@return string
local function text_at(root, rev, file)
	local spec = rev .. ":" .. (file.old_path or file.path)
	local committed = vim.system({ "git", "show", spec }, { cwd = root, text = true }):wait()
	return committed.code == 0 and committed.stdout or ""
end

--- The buffer's changes against old_text, staged or not, as the tint and ]h
--- visit both. Diffed here because gitsigns reports no hunks while it refreshes.
---@param old_text string
---@param buf integer
---@return GitHunk[]
local function hunks_against(old_text, buf)
	local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
	local indices = vim.text.diff(old_text, current, { result_type = "indices" })
	---@cast indices integer[][]
	return vim.tbl_map(function(hunk)
		return { removed = { start = hunk[1], count = hunk[2] }, added = { start = hunk[3], count = hunk[4] } }
	end, indices)
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
local function tint_changes(buf, hunks, old_lines, with_signs)
	vim.api.nvim_buf_clear_namespace(buf, tint_ns, 0, -1)
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

--- ]h and [h in a read-only copy, which gitsigns does not attach to: the first
--- line of the next or previous change.
---@param buf integer
---@param hunks GitHunk[]
local function map_hunk_motions(buf, hunks)
	local starts = {}
	for _, hunk in ipairs(hunks) do
		if hunk.added.count > 0 then
			table.insert(starts, hunk.added.start)
		end
	end
	local function go(forward)
		local line = vim.api.nvim_win_get_cursor(0)[1]
		local target
		for _, start in ipairs(starts) do
			if forward and start > line and not target then
				target = start
			elseif not forward and start < line then
				target = start
			end
		end
		if target then
			vim.api.nvim_win_set_cursor(0, { target, 0 })
		end
	end
	local next_hunk, prev_hunk = require("plugins.editor.motion_repeat").pair(function()
		go(true)
	end, function()
		go(false)
	end)
	vim.keymap.set("n", "]h", next_hunk, { buffer = buf, desc = "Git go to next changed hunk" })
	vim.keymap.set("n", "[h", prev_hunk, { buffer = buf, desc = "Git go to previous changed hunk" })
end

--- Collapses the file to its changes and puts the cursor on the first one.
---@param win integer
---@param buf integer
---@param hunks GitHunk[]
local function focus_changes(win, buf, hunks)
	folds.collapse(win, buf, hunks)
	if #hunks == 0 then
		return
	end
	vim.api.nvim_win_set_cursor(win, { math.max(hunks[1].added.start, 1), 0 })
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zz")
	end)
end

---@param file ChangedFile
---@return string
local function buffer_name_of(file)
	assert(panel, "buffer_name_of needs an open panel")
	if file.status == "D" then
		return deleted_buffer_name(file)
	end
	if panel.since and panel.since.to then
		return commit_buffer_name(panel.since.to.commit, file)
	end
	return vim.fs.joinpath(panel.root, file.path)
end

--- Closes a buffer the preview loaded once nothing shows it, so looking down the
--- list does not leave every file open. One with unsaved edits stays.
---@param buf integer?
local function close_unused_preview(buf)
	if not buf or not vim.api.nvim_buf_is_valid(buf) then
		return
	end
	if vim.bo[buf].modified or #vim.fn.win_findbuf(buf) > 0 then
		return
	end
	vim.api.nvim_buf_delete(buf, {})
end

--- Keeps a real file's before and after up to date while it is edited in the review.
---@param buf integer
local function retint_on_edits(buf)
	if #vim.api.nvim_get_autocmds({ group = edits_group, buffer = buf }) > 0 then
		return
	end
	vim.api.nvim_create_autocmd({ "TextChanged", "TextChangedI" }, {
		desc = "Show the edited file's changes against the panel's base",
		group = edits_group,
		buffer = buf,
		callback = function()
			local base = panel and panel.bases[buf]
			if base then
				tint_changes(buf, hunks_against(base.text, buf), base.lines, false)
			end
		end,
	})
end

--- Shows the file in the target window, at its first change, without moving there.
---@param file ChangedFile
---@return integer win
local function show_file(file)
	assert(panel, "show_file needs an open panel")
	local win = target_window()
	panel.target_win = win
	local previous_preview = panel.preview_buf
	if file.status == "D" then
		local buf = deleted_file_buffer(panel.root, panel.since, file)
		if buf then
			vim.api.nvim_win_set_buf(win, buf)
		end
		panel.preview_buf = nil
	elseif panel.since and panel.since.to then
		local to = panel.since.to
		local source = to.index and ":" or to.commit .. ":"
		local buf = git_file_buffer(panel.root, { source }, file.path, commit_buffer_name(to.commit, file))
		if buf then
			vim.api.nvim_win_set_buf(win, buf)
			local old_text = text_at(panel.root, panel.since.commit, file)
			local hunks = hunks_against(old_text, buf)
			tint_changes(buf, hunks, vim.split(old_text, "\n", { plain = true }), true)
			map_hunk_motions(buf, hunks)
			focus_changes(win, buf, hunks)
		end
		panel.preview_buf = nil
	else
		local path = buffer_name_of(file)
		local loaded_before = buffer_named(path) ~= nil
		vim.api.nvim_win_call(win, function()
			vim.cmd.edit(vim.fn.fnameescape(path))
		end)
		local buf = vim.api.nvim_win_get_buf(win)
		local text = text_at(panel.root, base_rev(panel.since), file)
		panel.bases[buf] = { text = text, lines = vim.split(text, "\n", { plain = true }) }
		local hunks = hunks_against(text, buf)
		tint_changes(buf, hunks, panel.bases[buf].lines, false)
		retint_on_edits(buf)
		focus_changes(win, buf, hunks)
		panel.preview_buf = not loaded_before and buf or nil
	end
	if previous_preview ~= panel.preview_buf then
		close_unused_preview(previous_preview)
	end
	return win
end

--- Shows the file under the panel's cursor unless it already is.
---@return integer? win showing it, or nil on a folder line
local function show_file_under_cursor()
	if not panel or not panel.ready then
		return nil
	end
	local file = panel.files_by_line[vim.api.nvim_win_get_cursor(panel.win)[1]]
	if not file then
		return nil
	end
	local target = panel.target_win
	if vim.api.nvim_win_is_valid(target) then
		local shown = vim.api.nvim_win_get_buf(target)
		-- A real file already on show, like the one the panel was opened from, still
		-- needs its before and after drawn; copies and deleted files are drawn as made.
		local drawn = panel.bases[shown] or file.status == "D" or (panel.since and panel.since.to)
		if drawn and vim.api.nvim_buf_get_name(shown) == buffer_name_of(file) then
			return target
		end
	end
	return show_file(file)
end

local function open_file_under_cursor()
	local win = show_file_under_cursor()
	if win then
		vim.api.nvim_set_current_win(win)
	end
end

---@param win integer
local function set_panel_window_options(win)
	local opts = vim.wo[win][0]
	opts.number = false
	opts.relativenumber = false
	opts.signcolumn = "no"
	opts.foldcolumn = "0"
	opts.foldenable = false
	opts.list = false
	opts.wrap = false
	opts.cursorline = true
	opts.winfixwidth = true
end

--- Puts the file and view the panel was opened from back in the target window,
--- then closes any preview and puts the folds and tint back.
---@param closed Panel
local function leave_review(closed)
	local win = closed.target_win
	if vim.api.nvim_win_is_valid(win) and vim.api.nvim_buf_is_valid(closed.origin_buf) then
		vim.api.nvim_win_set_buf(win, closed.origin_buf)
		vim.api.nvim_win_call(win, function()
			vim.fn.winrestview(closed.origin_view)
		end)
		vim.api.nvim_set_current_win(win)
	end
	close_unused_preview(closed.preview_buf)
	folds.release_all()
	vim.api.nvim_clear_autocmds({ group = edits_group })
	for buf in pairs(closed.bases) do
		if vim.api.nvim_buf_is_valid(buf) then
			vim.api.nvim_buf_clear_namespace(buf, tint_ns, 0, -1)
		end
	end
	-- Only the files as they are now were compared through gitsigns' base.
	if closed.since and not closed.since.to then
		set_gitsigns_base(nil, function() end)
	end
end

---@return integer
local function create_panel_buffer()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_name(buf, "Git changes")
	vim.bo[buf].bufhidden = "wipe"
	vim.bo[buf].filetype = "gitchanges"
	vim.bo[buf].modifiable = false

	vim.keymap.set("n", "<CR>", open_file_under_cursor, { buffer = buf, desc = "Git open the changed file" })
	vim.api.nvim_create_autocmd("BufEnter", {
		desc = "Relist changes on returning to the panel, since staging or committing elsewhere changes them",
		buffer = buf,
		callback = refresh,
	})
	vim.api.nvim_create_autocmd("CursorMoved", {
		desc = "Preview the file under the cursor",
		buffer = buf,
		-- Without it, opening the file skips its BufRead autocmds: no filetype, no gitsigns.
		nested = true,
		callback = function()
			show_file_under_cursor()
		end,
	})
	vim.api.nvim_create_autocmd("BufWipeout", {
		desc = "Return to where the panel was opened from, however it was closed",
		buffer = buf,
		callback = function()
			local closed = panel
			panel = nil
			-- Switching buffers in other windows is not safe while this one is being wiped.
			vim.schedule(function()
				if closed then
					leave_review(closed)
				end
			end)
		end,
	})
	return buf
end

---@param root string
---@param since Since?
---@param focus_path string? the file to start on, when it is in the list
local function open_panel(root, since, focus_path)
	local files = changed_files(root, since)
	if not files then
		return
	end
	if #files == 0 then
		vim.notify(since and "No changes since " .. since.summary or "No changes")
		return
	end

	local origin_win = vim.api.nvim_get_current_win()
	local origin_buf = vim.api.nvim_get_current_buf()
	local origin_view = vim.fn.winsaveview()
	local buf = create_panel_buffer()
	local width = panel_width(render(files, title_of(since)))
	local win = vim.api.nvim_open_win(buf, true, { split = "left", win = -1, width = width })
	set_panel_window_options(win)
	panel = {
		buf = buf,
		win = win,
		root = root,
		width = width,
		target_win = origin_win,
		files_by_line = {},
		origin_buf = origin_buf,
		origin_view = origin_view,
		since = since,
		ready = false,
		bases = {},
	}
	draw(files)
	if focus_path then
		vim.api.nvim_win_set_cursor(win, { line_of(panel.files_by_line, focus_path) or 1, 0 })
	end
	local opened = panel
	if since and since.to then
		opened.ready = true
		show_file_under_cursor()
		return
	end
	set_gitsigns_base(since and since.commit, function()
		if panel == opened then
			opened.ready = true
			show_file_under_cursor()
		end
	end)
end

--- Leaves the review straight away, where the wipe handler would only schedule
--- it, so a panel opened next does not have its tint undone. As the last window
--- the panel cannot close, so it gives way to an empty buffer instead.
local function close_panel()
	assert(panel, "close_panel needs an open panel")
	local closed = panel
	panel = nil
	local normal_wins = vim.tbl_filter(function(win)
		return vim.api.nvim_win_get_config(win).relative == ""
	end, vim.api.nvim_tabpage_list_wins(0))
	if #normal_wins == 1 and normal_wins[1] == closed.win then
		vim.api.nvim_win_set_buf(closed.win, vim.api.nvim_create_buf(true, false))
	else
		vim.api.nvim_win_close(closed.win, false)
	end
	leave_review(closed)
end

---@return string?
local function current_repo_root()
	local root = repo_root()
	if not root then
		vim.notify("Not inside a git repository", vim.log.levels.WARN)
	end
	return root
end

local function toggle_panel()
	if panel and vim.api.nvim_win_is_valid(panel.win) then
		close_panel()
		return
	end
	local root = current_repo_root()
	if root then
		open_panel(root, nil)
	end
end

---@param root string
---@param commit string
---@return Since?
local function since_of(root, commit)
	local summary = git_output(root, { "log", "-1", "--format=%h %s", commit })
	if not summary then
		return nil
	end
	local short = vim.split(summary, " ", { plain = true })[1]
	return { commit = short, summary = vim.trim(summary) }
end

--- The commit before commit, or nil for a repository's first commit.
---@param root string
---@param commit string
---@return string?
local function parent_of(root, commit)
	local result = vim.system(
		{ "git", "rev-parse", "--verify", "--quiet", "--short", commit .. "^" },
		{ cwd = root, text = true }
	):wait()
	return result.code == 0 and vim.trim(result.stdout) or nil
end

--- The range holding only what commit changed: from the commit before it, or for
--- a repository's first commit, from the empty tree.
---@param root string
---@param commit Since
---@return Since?
local function own_changes(root, commit)
	local since
	local parent = parent_of(root, commit.commit)
	if parent then
		since = since_of(root, parent)
	else
		local empty_tree = git_output(root, { "hash-object", "-t", "tree", "/dev/null" })
		since = empty_tree and { commit = vim.trim(empty_tree), summary = "the empty tree", label = "empty" }
	end
	if since then
		since.to = commit
	end
	return since
end

--- Opens the panel on since, replacing a panel already open.
---@param root string
---@param since Since
---@param focus_path string?
local function replace_panel(root, since, focus_path)
	if panel and vim.api.nvim_win_is_valid(panel.win) then
		close_panel()
	end
	open_panel(root, since, focus_path)
end

--- Opens the panel on the changes since older, up to newer or to the files as
--- they are now. When the files as they are now have nothing new since older, it
--- shows what older itself changed instead.
---@param root string
---@param older string
---@param newer string?
local function open_range(root, older, newer)
	local since = since_of(root, older)
	if not since then
		return
	end
	if newer then
		since.to = since_of(root, newer)
		if not since.to then
			return
		end
	elseif #(changed_files(root, since) or { true }) == 0 then
		vim.notify(("Nothing has changed since %s, so here is what it changed"):format(since.summary))
		since = own_changes(root, since)
		if not since then
			return
		end
	end
	replace_panel(root, since)
end

--- Opens the panel on what commit itself changed.
---@param root string
---@param commit string
---@param focus_path string?
local function open_commit(root, commit, focus_path)
	local picked = since_of(root, commit)
	local since = picked and own_changes(root, picked)
	if since then
		replace_panel(root, since, focus_path)
	end
end

--- Opens the panel on what is staged, against commit, replacing a panel already open.
---@param root string
---@param commit string
local function open_staged(root, commit)
	local since = since_of(root, commit)
	if not since then
		return
	end
	since.to = { commit = "staged", summary = "the staged files", index = true }
	local files = changed_files(root, since)
	if not files then
		return
	end
	if #files == 0 then
		vim.notify("Nothing staged")
		return
	end
	replace_panel(root, since)
end

---@class CommitRow
---@field commit string? its short hash; nil for the files as they are now
---@field author string
---@field when string how long ago, as git puts it
---@field subject string

--- The commits git log lists for range (HEAD's whole history when nil), newest
--- first; with mine, only those by the user's git email, whatever name they carry.
---@param root string
---@param range string?
---@param mine boolean
---@param lines string? only commits changing these lines, as git log -L names them
---@return CommitRow[]
local function commit_rows(root, range, mine, lines)
	local rows = {}
	local args = { "log", "--format=%h%x09%an%x09%ar%x09%s", range or "HEAD" }
	if lines then
		vim.list_extend(args, { "-L", lines, "--no-patch" })
	end
	if mine then
		local email = vim.trim(git_output(root, { "config", "user.email" }) or "")
		table.insert(args, "--author=" .. email)
	end
	local log = git_output(root, args) or ""
	for line in vim.gsplit(log, "\n", { trimempty = true }) do
		local fields = vim.split(line, "\t", { plain = true })
		table.insert(rows, { commit = fields[1], author = fields[2], when = fields[3], subject = fields[4] or "" })
	end
	return rows
end

--- A Telescope picker over commits: hash, author, how long ago and subject in
--- columns, typing matching the author as well as the subject. <C-o> switches
--- between everyone's commits and only yours. preview_command's output previews
--- on the right.
---@param title string
---@param rows_for fun(mine: boolean): CommitRow[]
---@param preview_command fun(commit: string?): string[]
---@param on_pick fun(row: CommitRow)
local function pick_commit(title, rows_for, preview_command, on_pick)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local entry_display = require("telescope.pickers.entry_display")

	local mine = false
	local rows = rows_for(mine)
	local author_width = 6
	for _, row in ipairs(rows) do
		author_width = math.max(author_width, vim.fn.strdisplaywidth(row.author))
	end
	local displayer = entry_display.create({
		separator = " ",
		items = { { width = 8 }, { width = math.min(author_width, 20) }, { width = 14 }, { remaining = true } },
	})

	---@param results CommitRow[]
	local function finder(results)
		return finders.new_table({
			results = results,
			---@param row CommitRow
			entry_maker = function(row)
				return {
					value = row,
					ordinal = table.concat({ row.commit or "", row.author, row.subject }, " "),
					display = function()
						return displayer({
							{ row.commit or "", "TelescopeResultsIdentifier" },
							{ row.author, "TelescopeResultsConstant" },
							{ row.when, "TelescopeResultsComment" },
							row.subject,
						})
					end,
				}
			end,
		})
	end

	---@param showing_mine boolean
	local function results_title(showing_mine)
		return showing_mine and "Your commits (<C-o> everyone's)" or "Everyone's commits (<C-o> yours)"
	end

	pickers
		.new({}, {
			prompt_title = title,
			results_title = results_title(mine),
			finder = finder(rows),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_termopen_previewer({
				get_command = function(entry)
					return preview_command(entry.value.commit)
				end,
			}),
			attach_mappings = function(prompt_bufnr, map)
				actions.select_default:replace(function()
					local entry = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if entry then
						-- A picker opened next has to wait for this one to finish closing.
						vim.schedule(function()
							on_pick(entry.value)
						end)
					end
				end)
				map({ "i", "n" }, "<C-o>", function()
					mine = not mine
					local picker = action_state.get_current_picker(prompt_bufnr)
					picker:refresh(finder(rows_for(mine)), { reset_prompt = false })
					picker.results_border:change_title(results_title(mine))
				end, { desc = "Git show only your commits, or everyone's" })
				return true
			end,
		})
		:find()
end

---@param root string
---@return fun(commit: string?): string[]
local function preview_own_diff(root)
	return function(commit)
		return { "git", "-C", root, "show", commit }
	end
end

--- Picks a commit from the log, then where the changes since it run up to: the
--- files as they are now, first, or a later commit (asked only when there is
--- one). Opens the panel on them.
local function pick_commit_then_open_panel()
	local root = current_repo_root()
	if not root then
		return
	end
	local function history(mine)
		return commit_rows(root, nil, mine)
	end
	pick_commit("Diff Changes Since Commit", history, preview_own_diff(root), function(older)
		-- With nothing after it, the second picker would only offer the files as they are now.
		if #commit_rows(root, older.commit .. "..HEAD", false) == 0 then
			open_range(root, older.commit, nil)
			return
		end
		local function later(mine)
			local rows = commit_rows(root, older.commit .. "..HEAD", mine)
			table.insert(rows, 1, { author = "", when = "", subject = "Your files as they are now" })
			return rows
		end
		local function preview_from_older(commit)
			return { "git", "-C", root, "diff", older.commit, commit }
		end
		pick_commit("Diff " .. older.commit .. " Up To", later, preview_from_older, function(newer)
			open_range(root, older.commit, newer.commit)
		end)
	end)
end

--- Picks a commit from the log and opens the panel on what it changed.
local function pick_commit_to_show()
	local root = current_repo_root()
	if not root then
		return
	end
	local function history(mine)
		return commit_rows(root, nil, mine)
	end
	pick_commit("Diff Commit", history, preview_own_diff(root), function(picked)
		open_commit(root, picked.commit)
	end)
end

--- The line of the committed file that a buffer line sits at, given the buffer's
--- changes from it. A changed line gives its old counterpart; a new line gives nil.
---@param hunks GitHunk[]
---@param line integer
---@return integer?
local function committed_line(hunks, line)
	local shift = 0
	for _, hunk in ipairs(hunks) do
		local added, removed = hunk.added, hunk.removed
		if added.count > 0 and line >= added.start and line < added.start + added.count then
			if removed.count == 0 then
				return nil
			end
			return removed.start + math.min(line - added.start, removed.count - 1)
		end
		-- A count of 0 puts start on the line before the gap.
		local next_added = added.start + math.max(added.count, 1)
		if line < next_added then
			break
		end
		shift = removed.start + math.max(removed.count, 1) - next_added
	end
	return line + shift
end

--- Where the buffer's lines first to last sit in the committed file, or nil when
--- all of them are new.
---@param hunks GitHunk[]
---@param first integer
---@param last integer
---@return integer? committed_first
---@return integer? committed_last
local function committed_range(hunks, first, last)
	local committed_first, committed_last
	for line = first, last do
		local committed = committed_line(hunks, line)
		if committed then
			committed_first = committed_first or committed
			committed_last = committed
		end
	end
	return committed_first, committed_last
end

--- The current file's path from root, or nil for a buffer that is no file in it.
---@param root string
---@return string?
local function path_in_repo(root)
	if vim.bo.buftype ~= "" then
		return nil
	end
	local real_path = vim.uv.fs_realpath(vim.api.nvim_buf_get_name(0))
	return real_path and vim.fs.relpath(root, real_path)
end

--- Lists the commits that changed lines first to last of the current file, each
--- previewed as its change to them. Picking one opens the panel on that commit,
--- at this file. git follows the lines from the last commit, so uncommitted edits
--- above them do not move the range onto other code.
---@param title string
---@param first integer
---@param last integer
local function pick_line_history(title, first, last)
	local root = current_repo_root()
	if not root then
		return
	end
	local path = path_in_repo(root)
	if not path then
		vim.notify("Git history needs a file in this repository", vim.log.levels.WARN)
		return
	end
	local committed_text = text_at(root, "HEAD", { path = path, status = "M" })
	local committed_first, committed_last = committed_range(hunks_against(committed_text, 0), first, last)
	if committed_text == "" or not committed_first then
		vim.notify("These lines have not been committed yet")
		return
	end

	local lines = ("%d,%d:%s"):format(committed_first, committed_last, path)
	-- The preview finds a commit by its place in the whole history, whoever's are listed.
	local place_in_history = {}
	for index, row in ipairs(commit_rows(root, nil, false, lines)) do
		place_in_history[row.commit] = index - 1
	end
	local function history(mine)
		return commit_rows(root, nil, mine, lines)
	end
	local function preview_change_to_lines(commit)
		return { "git", "-C", root, "log", "-L", lines, "--skip=" .. place_in_history[commit], "-n1" }
	end
	pick_commit("History of " .. title, history, preview_change_to_lines, function(picked)
		open_commit(root, picked.commit, path)
	end)
end

--- Lines first to last of the smallest function around the cursor, by the queries
--- ]f moves with, or nil outside any.
---@return integer? first
---@return integer? last
local function function_at_cursor()
	local parser = vim.treesitter.get_parser(0, nil, { error = false })
	local query = parser and vim.treesitter.query.get(parser:lang(), "textobjects")
	if not parser or not query then
		return nil
	end
	local row = vim.api.nvim_win_get_cursor(0)[1] - 1
	local first, last
	for id, node in query:iter_captures(parser:parse()[1]:root(), 0, row, row + 1) do
		local start_row, _, end_row, end_col = node:range()
		local final_row = end_col == 0 and end_row - 1 or end_row
		local around_cursor = start_row <= row and row <= final_row
		local smaller = not first or final_row - start_row < last - first
		if query.captures[id] == "function.outer" and around_cursor and smaller then
			first, last = start_row, final_row
		end
	end
	if not first then
		return nil
	end
	return first + 1, last + 1
end

local function pick_function_history()
	local first, last = function_at_cursor()
	if not first or not last then
		vim.notify("No function under the cursor; select lines to see their history", vim.log.levels.WARN)
		return
	end
	local signature = vim.trim(vim.api.nvim_buf_get_lines(0, first - 1, first, false)[1])
	pick_line_history(vim.fn.strcharpart(signature, 0, 40), first, last)
end

local function pick_selection_history()
	local first, last = vim.fn.line("v"), vim.fn.line(".")
	if first > last then
		first, last = last, first
	end
	vim.cmd.normal({ args = { vim.keycode("<Esc>") }, bang = true })
	pick_line_history(("lines %d-%d"):format(first, last), first, last)
end

local group = vim.api.nvim_create_augroup("git-changes-panel", { clear = true })

vim.api.nvim_create_autocmd("BufWritePost", {
	desc = "Relist changes in the open panel after a save",
	group = group,
	callback = refresh,
})

vim.api.nvim_create_autocmd("BufEnter", {
	desc = "Keep a previewed file open once it is entered, with <CR> or by moving to its window",
	group = group,
	callback = function(ev)
		if panel and ev.buf == panel.preview_buf and vim.api.nvim_get_current_win() ~= panel.win then
			panel.preview_buf = nil
		end
	end,
})

vim.keymap.set("n", "<leader>gd", toggle_panel, { desc = "Git diff toggle changed files panel" })
vim.keymap.set(
	"n",
	"<leader>gD",
	pick_commit_then_open_panel,
	{ desc = "Git diff files changed since a commit picked from the log, up to now or a later commit" }
)
vim.keymap.set("n", "<leader>gh", pick_function_history, { desc = "Git history of the function under the cursor" })
vim.keymap.set("x", "<leader>gh", pick_selection_history, { desc = "Git history of the selected lines" })

vim.api.nvim_create_user_command("GitChanges", function(opts)
	local root = current_repo_root()
	if not root then
		return
	end
	if opts.fargs[1] == "--cached" then
		open_staged(root, opts.fargs[2] or "HEAD")
	elseif opts.fargs[1] == "--commit" and opts.fargs[2] then
		open_commit(root, opts.fargs[2])
	elseif opts.fargs[1] == "--commit" then
		pick_commit_to_show()
	elseif #opts.fargs == 0 then
		pick_commit_then_open_panel()
	else
		open_range(root, opts.fargs[1], opts.fargs[2])
	end
end, {
	nargs = "*",
	desc = "Changed files panel: pick commits, the changes since older up to now or newer, --commit [commit] or --cached [commit]",
})
