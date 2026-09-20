--- Floating prompt used for every vim.ui.input call.
--- Asks next to the cursor instead of on the command line, so the code being
--- renamed or the command being edited stays in view. <CR> confirms and <Esc>
--- cancels, as on the command line; <Tab> completes when the caller asked for it.

---@param prompt? string
---@return string
local function title_of(prompt)
	local text = vim.trim(prompt or ""):gsub("[:%s]+$", "")
	return text == "" and "Input" or text
end

---@param default string
---@param title string
---@return integer
local function window_width(default, title)
	local wanted = math.max(vim.fn.strdisplaywidth(default) + 1, vim.fn.strdisplaywidth(title) + 2, 24)
	return math.min(wanted, math.max(vim.o.columns - 4, 1))
end

---@param buf integer
---@param completion string a 'complete' option kind, e.g. "file"
local function complete_line(buf, completion)
	local line = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
	local ok, matches = pcall(vim.fn.getcompletion, line, completion)
	if not ok or #matches == 0 then
		return
	end
	vim.fn.complete(1, matches)
end

---@param opts {prompt?: string, default?: string, completion?: string}
---@param on_confirm fun(input: string?)
local function float_input(opts, on_confirm)
	opts = opts or {}
	local default = opts.default or ""
	local title = title_of(opts.prompt)

	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, { default })

	local win = vim.api.nvim_open_win(buf, true, {
		relative = "cursor",
		row = 1,
		col = 0,
		width = window_width(default, title),
		height = 1,
		style = "minimal",
		border = vim.o.winborder ~= "" and vim.o.winborder or "rounded",
		title = " " .. title .. " ",
		title_pos = "left",
	})
	vim.wo[win].wrap = false

	-- vim.ui.input's contract is exactly one on_confirm call, and callers chain off it.
	local answered = false
	---@param value string?
	local function finish(value)
		if answered then
			return
		end
		answered = true
		-- Mode is global: closing the window while still inserting would leave the
		-- buffer underneath in insert mode.
		vim.cmd.stopinsert()
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
		on_confirm(value)
	end

	vim.keymap.set({ "n", "i" }, "<CR>", function()
		finish(vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1])
	end, { buffer = buf })

	vim.keymap.set({ "n", "i" }, "<Esc>", function()
		finish(nil)
	end, { buffer = buf })

	vim.keymap.set("i", "<C-c>", function()
		finish(nil)
	end, { buffer = buf })

	if opts.completion then
		vim.keymap.set("i", "<Tab>", function()
			complete_line(buf, opts.completion)
		end, { buffer = buf })
	end

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = function()
			finish(nil)
		end,
	})

	vim.cmd.startinsert({ bang = true })
end

vim.ui.input = float_input
