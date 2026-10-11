--- Changed files panel. <leader>gd lists the repository's uncommitted changes in
--- a split on the left, grouped by folder, and <leader>gD everything changed since
--- a commit picked from the log. The file under the cursor previews on the right
--- at its first change, folded down to the changes and the lines around them,
--- with gitsigns tinting the changed lines and words; <CR> moves into it. The
--- panel stays open, and <leader>gd closes it, returns to the file it was opened
--- from and puts the folds, tint and gitsigns' base back.

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

---@class ChangedFile
---@field path string relative to the repository root
---@field status string one git status letter, or "?" for untracked
---@field old_path string? where a renamed or copied file came from

---@class Since
---@field commit string the commit the changes are listed since
---@field summary string its short hash and subject, shown above the list

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

---@param enabled boolean
local function set_change_tint(enabled)
	gitsigns.toggle_linehl(enabled)
	gitsigns.toggle_word_diff(enabled)
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

	local content = render(files, panel.since and "since " .. panel.since.summary)
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

--- A deleted file has nothing on disk, so it shows what was removed: with since,
--- its commit's copy; otherwise the staged copy if there is one, else the last commit's.
---@param root string
---@param since Since?
---@param file ChangedFile
---@return integer?
local function deleted_file_buffer(root, since, file)
	local name = deleted_buffer_name(file)
	local existing = buffer_named(name)
	if existing then
		return existing
	end

	local sources = since and { since.commit .. ":" } or { ":", "HEAD:" }
	local result
	for _, source in ipairs(sources) do
		result = vim.system({ "git", "show", source .. file.path }, { cwd = root, text = true }):wait()
		if result.code == 0 then
			break
		end
	end
	if result.code ~= 0 then
		vim.notify("No earlier version of " .. file.path, vim.log.levels.WARN)
		return nil
	end

	local buf = vim.api.nvim_create_buf(false, true)
	local lines = vim.split(result.stdout, "\n", { plain = true })
	if lines[#lines] == "" then
		table.remove(lines)
	end
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
	vim.api.nvim_buf_set_name(buf, name)
	vim.bo[buf].filetype = vim.filetype.match({ filename = file.path, buf = buf }) or ""
	vim.bo[buf].modifiable = false
	vim.bo[buf].bufhidden = "wipe"
	return buf
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

--- The buffer's changes since rev, staged or not, as gitsigns tints and ]h
--- visits both. Diffed here because gitsigns reports no hunks while it refreshes,
--- which turning the tint on sets off. A file rev does not have, untracked or
--- added since, has none: it is all new.
---@param root string
---@param rev string
---@param file ChangedFile
---@param buf integer
---@return GitHunk[]
local function hunks_since(root, rev, file, buf)
	local spec = rev .. ":" .. (file.old_path or file.path)
	local committed = vim.system({ "git", "show", spec }, { cwd = root, text = true }):wait()
	if committed.code ~= 0 then
		return {}
	end
	local current = table.concat(vim.api.nvim_buf_get_lines(buf, 0, -1, false), "\n") .. "\n"
	local indices = vim.text.diff(committed.stdout, current, { result_type = "indices" })
	---@cast indices integer[][]
	return vim.tbl_map(function(hunk)
		return { added = { start = hunk[3], count = hunk[4] } }
	end, indices)
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
	else
		local path = buffer_name_of(file)
		local loaded_before = buffer_named(path) ~= nil
		vim.api.nvim_win_call(win, function()
			vim.cmd.edit(vim.fn.fnameescape(path))
		end)
		local buf = vim.api.nvim_win_get_buf(win)
		focus_changes(win, buf, hunks_since(panel.root, base_rev(panel.since), file, buf))
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
	if
		vim.api.nvim_win_is_valid(target)
		and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(target)) == buffer_name_of(file)
	then
		return target
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
	set_change_tint(false)
	if closed.since then
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
local function open_panel(root, since)
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
	local width = panel_width(render(files, since and "since " .. since.summary))
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
	}
	draw(files)
	set_change_tint(true)
	local opened = panel
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

--- Picks a commit from the log, with each one's diff previewed, and opens the
--- panel on everything changed since it, replacing a panel already open.
local function pick_commit_then_open_panel()
	local root = current_repo_root()
	if not root then
		return
	end
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	require("telescope.builtin").git_commits({
		cwd = root,
		prompt_title = "Diff Changes Since Commit",
		-- Replaces the picker's own <CR>, which would check the commit out.
		attach_mappings = function(prompt_bufnr)
			actions.select_default:replace(function()
				local entry = action_state.get_selected_entry()
				actions.close(prompt_bufnr)
				if not entry then
					return
				end
				if panel and vim.api.nvim_win_is_valid(panel.win) then
					close_panel()
				end
				open_panel(root, { commit = entry.value, summary = entry.value .. " " .. entry.msg })
			end)
			return true
		end,
	})
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
	{ desc = "Git diff files changed since a commit picked from the log" }
)
