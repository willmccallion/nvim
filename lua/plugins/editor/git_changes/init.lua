--- Changed files panel. <leader>gd lists the repository's uncommitted changes in
--- a split on the left, grouped by folder, and <leader>gD everything changed since
--- a commit picked from the log, up to the files as they are now or to a later
--- commit picked next. The file under the cursor previews on the right at its
--- first change, folded down to the changes and the lines around them; <leader>gz
--- shows whole files instead until pressed again or nvim quits. Each change
--- shows as a before and after: the old lines in red above the new ones in green,
--- the part that differs marked in both; <CR> moves into it. Files as they are now
--- are the real ones, kept up to date as you edit; a later commit's are read-only
--- copies. <leader>yc in the panel copies its commit's hash. The panel stays open,
--- and <leader>gd closes it, returns to the file it was opened from and puts the
--- folds, colours and gitsigns' base back.
--- <leader>gh lists the commits that changed the function under the cursor, or the
--- selected lines, and opens the panel on the one picked.
--- :GitChanges [older [newer]] opens the same from the command line (g diff does),
--- :GitChanges --commit [commit] what one commit changed, picked from the log when
--- not given, and :GitChanges --cached [commit] what is staged against commit, HEAD
--- by default.

local changes = require("plugins.editor.git_changes.changes")
local commits = require("plugins.editor.git_changes.commits")
local folds = require("plugins.editor.git_changes.folds")
local git = require("plugins.editor.git_changes.git")
local line_history = require("plugins.editor.git_changes.line_history")
local panel = require("plugins.editor.git_changes.panel")

--- Opens the panel on since, or says there is nothing to show and leaves any open one.
---@param root string
---@param since Since?
---@param focus_path string?
local function open_listing(root, since, focus_path)
	local files = changes.list(root, since)
	if not files then
		return
	end
	if #files == 0 then
		vim.notify(changes.nothing_message(since))
		return
	end
	panel.replace(root, since, files, focus_path)
end

local function toggle_panel()
	if panel.is_open() then
		panel.close()
		return
	end
	local root = git.current_root()
	if root then
		open_listing(root, nil)
	end
end

--- Opens the panel on the changes since older, up to newer or to the files as
--- they are now. When the files as they are now have nothing new since older, it
--- shows what older itself changed instead.
---@param root string
---@param older string
---@param newer string?
local function open_range(root, older, newer)
	local since = changes.since_of(root, older)
	if not since then
		return
	end
	if newer then
		local to = changes.since_of(root, newer)
		if not to then
			return
		end
		since.to = changes.commit_end(to.commit)
		open_listing(root, since)
		return
	end
	local files = changes.list(root, since)
	if not files then
		return
	end
	if #files > 0 then
		panel.replace(root, since, files)
		return
	end
	vim.notify(("Nothing has changed since %s, so here is what it changed"):format(since.summary))
	local own = changes.own_changes(root, since)
	if own then
		open_listing(root, own)
	end
end

--- Opens the panel on what commit itself changed.
---@param root string
---@param commit string
---@param focus_path string?
local function open_commit(root, commit, focus_path)
	local picked = changes.since_of(root, commit)
	local since = picked and changes.own_changes(root, picked)
	if since then
		open_listing(root, since, focus_path)
	end
end

--- Opens the panel on what is staged, against commit, replacing a panel already open.
---@param root string
---@param commit string
local function open_staged(root, commit)
	local since = changes.since_of(root, commit)
	if not since then
		return
	end
	since.to = changes.STAGED
	open_listing(root, since)
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
	local root = git.current_root()
	if not root then
		return
	end
	local function history(mine)
		return commits.rows(root, nil, mine)
	end
	commits.pick("Diff Changes Since Commit", history, preview_own_diff(root), function(older)
		-- With nothing after it, the second picker would only offer the files as they are now.
		if #commits.rows(root, older.commit .. "..HEAD", false) == 0 then
			open_range(root, older.commit, nil)
			return
		end
		local function later(mine)
			local rows = commits.rows(root, older.commit .. "..HEAD", mine)
			table.insert(rows, 1, { author = "", when = "", subject = "Your files as they are now" })
			return rows
		end
		local function preview_from_older(commit)
			return { "git", "-C", root, "diff", older.commit, commit }
		end
		commits.pick("Diff " .. older.commit .. " Up To", later, preview_from_older, function(newer)
			open_range(root, older.commit, newer.commit)
		end)
	end)
end

--- Picks a commit from the log and opens the panel on what it changed, with an
--- <Uncommitted> row below the newest commit when the files differ from it.
local function pick_commit_to_show()
	local root = git.current_root()
	if not root then
		return
	end
	local has_uncommitted = #(changes.list(root, nil) or {}) > 0
	local function history(mine)
		local rows = commits.rows(root, nil, mine)
		if has_uncommitted then
			table.insert(rows, 1, { author = "", when = "", subject = "<Uncommitted>" })
		end
		return rows
	end
	local own_diff = preview_own_diff(root)
	local function preview(commit)
		if commit then
			return own_diff(commit)
		end
		return { "sh", "-c", 'git -C "$1" status --short && git -C "$1" diff HEAD', "sh", root }
	end
	commits.pick("Diff Commit", history, preview, function(picked)
		if picked.commit then
			open_commit(root, picked.commit)
		else
			open_listing(root, nil)
		end
	end)
end

vim.keymap.set("n", "<leader>gd", toggle_panel, { desc = "Git diff toggle changed files panel" })
vim.keymap.set(
	"n",
	"<leader>gD",
	pick_commit_then_open_panel,
	{ desc = "Git diff files changed since a commit picked from the log, up to now or a later commit" }
)
vim.keymap.set("n", "<leader>gz", function()
	if folds.toggle_whole_files() then
		vim.notify("Git changes previews show whole files")
	else
		vim.notify("Git changes previews fold to their changes")
	end
end, { desc = "Git toggle whole files in the changed files panel's previews" })
vim.keymap.set("n", "<leader>gh", function()
	line_history.pick_function(open_commit)
end, { desc = "Git history of the function under the cursor" })
vim.keymap.set("x", "<leader>gh", function()
	line_history.pick_selection(open_commit)
end, { desc = "Git history of the selected lines" })

vim.api.nvim_create_user_command("GitChanges", function(opts)
	local root = git.current_root()
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
