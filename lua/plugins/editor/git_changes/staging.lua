--- Staging and committing from nvim: the changes panel's s, . and c, and <leader>gf,
--- <leader>g. and <leader>gC anywhere. A message gets g c's checks (the fish function
--- __g_message_problems), and a commit is offered for pushing, as g c does. Commits and
--- pushes run in the background, since hooks can take a while.

local changes = require("plugins.editor.git_changes.changes")
local git = require("plugins.editor.git_changes.git")

local M = {}

---@param count integer
---@param noun string
---@return string
local function count_of(count, noun)
	return ("%d %s%s"):format(count, noun, count == 1 and "" or "s")
end

---@param root string
---@param args string[]
---@return boolean # whether git exited 0
local function succeeds(root, args)
	return vim.system(vim.list_extend({ "git" }, args), { cwd = root }):wait().code == 0
end

---@param file ChangedFile
---@return string[] its path, after the one it was renamed from
local function paths_of(file)
	return file.old_path and { file.old_path, file.path } or { file.path }
end

--- Stages the file, or unstages it when all of it is staged already.
---@param root string
---@param file ChangedFile
---@return boolean # false when git failed, which it reports
function M.toggle_file(root, file)
	local args
	if file.staged ~= "all" then
		args = { "add", "--", file.path }
	elseif succeeds(root, { "rev-parse", "--verify", "--quiet", "HEAD" }) then
		args = vim.list_extend({ "restore", "--staged", "--" }, paths_of(file))
	else
		-- Before the first commit there is no HEAD to restore the index from.
		args = vim.list_extend({ "rm", "--cached", "--quiet", "--" }, paths_of(file))
	end
	return git.output(root, args) ~= nil
end

--- Stages every change, untracked files and deletions too, as `git add -A` from the top.
---@param root string
---@return boolean # false when git failed, which it reports
function M.stage_all(root)
	if git.output(root, { "add", "-A" }) == nil then
		return false
	end
	vim.notify("Staged everything")
	return true
end

--- Picks files with a preview of what staging each adds. <Tab> marks several, and <CR>
--- takes the marked ones, or the one under the cursor when none are marked.
---@param root string
---@param files ChangedFile[]
---@param on_pick fun(paths: string[])
function M.pick_files(root, files, on_pick)
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local previewers = require("telescope.previewers")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")

	pickers
		.new({}, {
			prompt_title = "Stage Files (<Tab> marks several)",
			finder = finders.new_table({
				results = files,
				---@param file ChangedFile
				entry_maker = function(file)
					return { value = file, ordinal = file.path, display = ("%s %s"):format(file.status, file.path) }
				end,
			}),
			sorter = conf.generic_sorter({}),
			previewer = previewers.new_termopen_previewer({
				get_command = function(entry)
					local file = entry.value
					if file.status == "?" then
						return { "git", "-C", root, "diff", "--no-index", "--", "/dev/null", file.path }
					end
					return { "git", "-C", root, "diff", "--", file.path }
				end,
			}),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local marked = action_state.get_current_picker(prompt_bufnr):get_multi_selection()
					local picked = #marked > 0 and marked or { action_state.get_selected_entry() }
					actions.close(prompt_bufnr)
					local paths = vim.tbl_map(function(entry)
						return entry.value.path
					end, picked)
					if #paths > 0 then
						vim.schedule(function()
							on_pick(paths)
						end)
					end
				end)
				return true
			end,
		})
		:find()
end

--- Picks among the files with something unstaged, and stages the ones picked.
---@param root string
---@param on_staged fun()
function M.pick_and_stage(root, on_staged)
	local files = changes.list(root, nil)
	if not files then
		return
	end
	local unstaged = vim.tbl_filter(function(file)
		return file.staged ~= "all"
	end, files)
	if #unstaged == 0 then
		vim.notify("Nothing to stage")
		return
	end
	M.pick_files(root, unstaged, function(paths)
		if git.output(root, vim.list_extend({ "add", "--" }, paths)) ~= nil then
			vim.notify("Staged " .. count_of(#paths, "file"))
			on_staged()
		end
	end)
end

--- What g c finds wrong with a message, one problem a line. When the check itself
--- can't run, it says so and finds nothing, so a commit is never blocked by it.
---@param message string
---@return string[]
local function message_problems(message)
	local result = vim.system({ "fish", "-c", "__g_message_problems $argv", "--", message }, { text = true }):wait()
	if result.code ~= 0 then
		vim.notify("Couldn't check the commit message: " .. vim.trim(result.stderr), vim.log.levels.WARN)
		return {}
	end
	return vim.split(vim.trim(result.stdout), "\n", { trimempty = true })
end

--- Offers to push to the branch's upstream, or to origin when it has none yet.
---@param root string
local function offer_push(root)
	local upstream = vim.system({ "git", "rev-parse", "--abbrev-ref", "@{upstream}" }, { cwd = root, text = true })
		:wait()
	local question, args, where
	if upstream.code == 0 then
		where = vim.trim(upstream.stdout)
		question, args = ("Push to %s?"):format(where), { "push", "--quiet" }
	else
		local branch = vim.trim(git.output(root, { "branch", "--show-current" }) or "")
		if branch == "" or not succeeds(root, { "remote", "get-url", "origin" }) then
			return
		end
		where = "origin/" .. branch
		question = ("Push %s to origin (first push)?"):format(branch)
		args = { "push", "--quiet", "--set-upstream", "origin", branch }
	end
	vim.ui.select({ "Push", "Not now" }, { prompt = question }, function(choice)
		if choice ~= "Push" then
			return
		end
		vim.notify("Pushing to " .. where .. "…")
		vim.system(
			vim.list_extend({ "git" }, args),
			{ cwd = root, text = true },
			vim.schedule_wrap(function(result)
				if result.code == 0 then
					vim.notify("Pushed to " .. where)
				else
					vim.notify("git push failed: " .. vim.trim(result.stderr), vim.log.levels.ERROR)
				end
			end)
		)
	end)
end

---@param root string
---@param message string
---@param on_committed fun()
local function commit_with(root, message, on_committed)
	vim.notify("Committing…")
	vim.system(
		{ "git", "commit", "--quiet", "-m", message },
		{ cwd = root, text = true },
		vim.schedule_wrap(function(result)
			if result.code ~= 0 then
				vim.notify("git commit failed: " .. vim.trim(result.stderr .. result.stdout), vim.log.levels.ERROR)
				return
			end
			vim.notify("Committed " .. vim.trim(git.output(root, { "log", "-1", "--format=%h %s" }) or ""))
			on_committed()
			offer_push(root)
		end)
	)
end

--- Asks for the message, then for confirmation when g c finds something wrong with it,
--- going back to the message, as typed, to edit it.
---@param root string
---@param typed string
---@param on_committed fun()
local function ask_message(root, typed, on_committed)
	vim.ui.input({ prompt = "Commit message", default = typed }, function(message)
		if not message or vim.trim(message) == "" then
			return
		end
		local problems = message_problems(message)
		if #problems == 0 then
			commit_with(root, message, on_committed)
			return
		end
		local prompt = table.concat(problems, "; ") .. ". Commit anyway?"
		vim.ui.select({ "Commit anyway", "Edit the message" }, { prompt = prompt }, function(choice)
			if choice == "Commit anyway" then
				commit_with(root, message, on_committed)
			elseif choice == "Edit the message" then
				ask_message(root, message, on_committed)
			end
		end)
	end)
end

--- Commits what is staged, first picking files to stage when nothing is. on_changed
--- runs after staging and after the commit, so a panel can show them.
---@param root string
---@param on_changed fun()
function M.commit(root, on_changed)
	if succeeds(root, { "diff", "--cached", "--quiet" }) then
		M.pick_and_stage(root, function()
			on_changed()
			ask_message(root, "", on_changed)
		end)
		return
	end
	ask_message(root, "", on_changed)
end

return M
