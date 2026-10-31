--- Listing commits, and a Telescope picker over them.

local git = require("plugins.editor.git_changes.git")

local M = {}

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
function M.rows(root, range, mine, lines)
	local rows = {}
	local args = { "log", "--format=%h%x09%an%x09%ar%x09%s", range or "HEAD" }
	if lines then
		vim.list_extend(args, { "-L", lines, "--no-patch" })
	end
	if mine then
		local email = vim.trim(git.output(root, { "config", "user.email" }) or "")
		table.insert(args, "--author=" .. email)
	end
	local log = git.output(root, args) or ""
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
function M.pick(title, rows_for, preview_command, on_pick)
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

return M
