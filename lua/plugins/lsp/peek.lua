--- Peeks at a definition without leaving the code under the cursor, in a float or
--- a split. The float holds the whole file, opened at the definition, so it reads
--- on in either direction. Pressing the key again moves into it, q closes it and
--- <CR> goes to the line it is on. The split shows the real file and stays open,
--- each peek reusing it rather than opening another.

local FOCUS_ID = "peek_definition"
local MAX_WIDTH = 100
local HEIGHT = 20

local M = {}

---@type integer?
local split_win = nil

---@class PeekTarget
---@field path string
---@field line integer 1-based

--- The first definition any server gave. A LocationLink's targetRange starts at
--- the whole definition, comments included, where a Location has only the name.
---@param results table<integer, {result: lsp.Location|lsp.Location[]|lsp.LocationLink[]?}>
---@return PeekTarget?
local function first_definition(results)
	for _, response in pairs(results) do
		local result = response.result
		local location = vim.islist(result) and result[1] or result
		if location then
			local range = location.targetRange or location.range
			return { path = vim.uri_to_fname(location.targetUri or location.uri), line = range.start.line + 1 }
		end
	end
	return nil
end

--- An open buffer can have unsaved edits the file on disk does not.
---@param path string
---@return string[]
local function lines_of(path)
	local buf = vim.fn.bufnr(path)
	if buf ~= -1 and vim.api.nvim_buf_is_loaded(buf) then
		return vim.api.nvim_buf_get_lines(buf, 0, -1, false)
	end
	return vim.fn.readfile(path)
end

---@param buf integer
---@param filetype string
local function highlight(buf, filetype)
	local lang = vim.treesitter.language.get_lang(filetype)
	if lang and vim.treesitter.language.add(lang) then
		vim.treesitter.start(buf, lang)
	else
		vim.bo[buf].syntax = filetype
	end
end

---@param win integer
---@param path string
local function go_to_line_in_float(win, path)
	local line = vim.api.nvim_win_get_cursor(win)[1]
	vim.api.nvim_win_close(win, true)
	vim.cmd("normal! m'")
	vim.cmd.edit(vim.fn.fnameescape(path))
	vim.api.nvim_win_set_cursor(0, { line, 0 })
	vim.cmd("normal! zz")
end

---@param target PeekTarget
local function open_float(target)
	local lines = lines_of(target.path)
	local buf, win = vim.lsp.util.open_floating_preview(lines, nil, {
		focus_id = FOCUS_ID,
		width = math.min(MAX_WIDTH, vim.o.columns - 4),
		height = HEIGHT,
		wrap = false,
		title = " " .. vim.fn.fnamemodify(target.path, ":~:.") .. " ",
	})
	-- A second press only moves into the float, which keeps its place.
	if vim.api.nvim_get_current_win() == win then
		return
	end

	highlight(buf, vim.filetype.match({ filename = target.path, contents = lines }) or "")
	vim.wo[win].number = true
	vim.wo[win].cursorline = true
	vim.api.nvim_win_set_cursor(win, { target.line, 0 })
	vim.api.nvim_win_call(win, function()
		vim.cmd("normal! zt")
	end)
	vim.keymap.set("n", "<CR>", function()
		go_to_line_in_float(win, target.path)
	end, { buffer = buf, desc = "LSP go to this line" })
end

---@return boolean
local function split_is_on_this_tabpage()
	return split_win ~= nil
		and vim.api.nvim_win_is_valid(split_win)
		and vim.api.nvim_win_get_tabpage(split_win) == vim.api.nvim_get_current_tabpage()
end

---@param target PeekTarget
local function show_in_split(target)
	if not split_is_on_this_tabpage() then
		split_win = vim.api.nvim_open_win(0, false, { split = "right", win = 0 })
	end
	vim.api.nvim_win_call(split_win, function()
		vim.cmd.edit(vim.fn.fnameescape(target.path))
		vim.api.nvim_win_set_cursor(0, { target.line, 0 })
		vim.cmd("normal! zt")
	end)
end

---@param show fun(target: PeekTarget)
local function with_definition(show)
	local function position_params(client)
		return vim.lsp.util.make_position_params(0, client.offset_encoding)
	end
	vim.lsp.buf_request_all(0, "textDocument/definition", position_params, function(results)
		local target = first_definition(results)
		if target then
			show(target)
		else
			vim.notify("No definition found")
		end
	end)
end

function M.definition()
	with_definition(open_float)
end

function M.definition_in_split()
	with_definition(show_in_split)
end

return M
