--- What the file and grep pickers share about their filters (the globs after two spaces):
--- the ones saved for the project fill the prompt when the picker opens, with the cursor
--- before them; the results border names the ones in use; <C-e> drops them; and closing
--- the picker saves them for next time (saved_filters.lua).

local glob = require("plugins.editor.telescope.glob")
local saved_filters = require("plugins.editor.telescope.saved_filters")

local RESULTS_TITLE = "Results"

local M = {}

---@class telescope.FilterSession
---@field picker string saved_filters' name for the picker
---@field folder string the folder searched
---@field globs string[] the ones in use
---@field prompt_bufnr integer? once the picker is open

--- The results border's title: the filters in use, or the usual title without any.
---@param globs string[]
---@return string
function M.label(globs)
	if #globs == 0 then
		return RESULTS_TITLE
	end
	return "Filters: " .. table.concat(globs, " · ")
end

--- A session for a picker about to open in the working folder, with its saved filters.
---@param picker string
---@return telescope.FilterSession
function M.start(picker)
	local folder = vim.fn.getcwd()
	return { picker = picker, folder = folder, globs = saved_filters.load(picker, folder) }
end

--- Takes the globs a prompt now has, relabelling the results when they changed.
---@param session telescope.FilterSession
---@param globs string[]
---@return boolean changed
function M.use(session, globs)
	if vim.deep_equal(globs, session.globs) then
		return false
	end
	session.globs = globs
	if session.prompt_bufnr then
		local picker = require("telescope.actions.state").get_current_picker(session.prompt_bufnr)
		picker.layout.results.border:change_title(M.label(globs))
	end
	return true
end

---@param prompt_bufnr integer
local function drop_filters(prompt_bufnr)
	local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
	local query = glob.split(picker:_get_prompt())
	picker:set_prompt(query)
end

---@param prompt_bufnr integer
local function put_cursor_before_filters(prompt_bufnr)
	local picker = require("telescope.actions.state").get_current_picker(prompt_bufnr)
	vim.api.nvim_win_set_cursor(picker.prompt_win, { 1, #picker.prompt_prefix })
end

--- Telescope picker options that carry the session: its filters in the prompt and the label,
--- <C-e>, and saving them on close.
---@param session telescope.FilterSession
---@return table
function M.picker_opts(session)
	return {
		default_text = #session.globs > 0 and "  " .. table.concat(session.globs, " ") or nil,
		results_title = M.label(session.globs),
		attach_mappings = function(prompt_bufnr, map)
			session.prompt_bufnr = prompt_bufnr
			for _, mode in ipairs({ "i", "n" }) do
				map(mode, "<C-e>", drop_filters, { desc = "Drop the filters after the two spaces" })
			end
			vim.api.nvim_create_autocmd("BufWipeout", {
				desc = "Remember the picker's filters for this project",
				buffer = prompt_bufnr,
				once = true,
				callback = function()
					saved_filters.save(session.picker, session.folder, session.globs)
				end,
			})
			if #session.globs > 0 then
				-- The saved filters fill the prompt; the search goes before them.
				vim.schedule(function()
					put_cursor_before_filters(prompt_bufnr)
				end)
			end
			return true
		end,
	}
end

return M
