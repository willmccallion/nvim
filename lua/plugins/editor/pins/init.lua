--- Pinned files: a short list per project of the files being worked in, each a key
--- away. <leader>a pins the current file, <leader>1 to <leader>4 open pins 1 to 4
--- where the cursor last was in them, and <leader>A opens the list as a buffer to
--- reorder or delete lines. Kept in stdpath("data"), so nothing is written into
--- repositories.

local json_file = require("lib.json_file")
local list = require("plugins.editor.pins.list")

local STORE_PATH = vim.fs.joinpath(vim.fn.stdpath("data"), "pins.json")

local KEYED_PINS = 4

--- The git root of the current buffer's file, else the working directory.
---@return string
local function project_root()
	local name = vim.api.nvim_buf_get_name(0)
	local start = (vim.bo.buftype == "" and name ~= "") and vim.fs.dirname(name) or vim.fn.getcwd()
	return vim.fs.root(start, ".git") or vim.fn.getcwd()
end

---@param root string
---@return string[]
local function load(root)
	local all = json_file.read(STORE_PATH) or {}
	return all[root] or {}
end

--- Refuses to write if the existing file is corrupt, so it is never clobbered.
---@param root string
---@param pins string[]
local function save(root, pins)
	local all = json_file.read(STORE_PATH)
	if not all then
		return
	end
	all[root] = #pins > 0 and pins or nil
	json_file.write(STORE_PATH, all)
end

---@param root string
---@param path string
---@return string
local function absolute(root, path)
	return vim.startswith(path, "/") and path or vim.fs.joinpath(root, path)
end

---@param root string
---@param path string as pinned
local function open_pin(root, path)
	local file = absolute(root, path)
	if not vim.uv.fs_stat(file) then
		vim.notify(("Pinned %s no longer exists; <leader>A edits the pins"):format(path), vim.log.levels.WARN)
		return
	end
	-- An already loaded buffer reopens where its cursor was; a new one is put back
	-- by the BufReadPost autocmd that restores the last position.
	vim.cmd.edit(vim.fn.fnameescape(file))
end

local function pin_current_file()
	local name = vim.api.nvim_buf_get_name(0)
	if vim.bo.buftype ~= "" or name == "" then
		vim.notify("Only a file can be pinned", vim.log.levels.WARN)
		return
	end
	local root = project_root()
	local path = vim.fs.relpath(root, name) or name
	local pins, number = list.add(load(root), path)
	save(root, pins)

	local message = ("Pinned %s as %d"):format(path, number)
	if number > KEYED_PINS then
		message = message .. ("; <leader>A moves it into 1-%d, which have keys"):format(KEYED_PINS)
	end
	vim.notify(message)
end

---@param number integer
local function go_to_pin(number)
	local root = project_root()
	local path = load(root)[number]
	if not path then
		vim.notify(("No pin %d in this project; <leader>a pins the current file"):format(number), vim.log.levels.INFO)
		return
	end
	open_pin(root, path)
end

--- The list is a buffer of paths, one per line, numbered by the line numbers; it is
--- saved when the window closes, so moving or deleting lines is all editing takes.
local function edit_pins()
	local root = project_root()
	local buf = vim.api.nvim_create_buf(false, true)
	vim.bo[buf].bufhidden = "wipe"
	vim.api.nvim_buf_set_lines(buf, 0, -1, false, load(root))

	local width = math.min(math.max(60, math.floor(vim.o.columns * 0.5)), math.max(vim.o.columns - 4, 1))
	local height = math.min(10, math.max(vim.o.lines - 6, 1))
	local win = vim.api.nvim_open_win(buf, true, {
		relative = "editor",
		row = math.floor((vim.o.lines - height) / 2) - 1,
		col = math.floor((vim.o.columns - width) / 2),
		width = width,
		height = height,
		border = vim.o.winborder ~= "" and vim.o.winborder or "rounded",
		title = (" Pins: %s "):format(vim.fn.fnamemodify(root, ":~")),
		title_pos = "left",
		footer = " <CR> open · q close · dd unpin · reorder lines ",
		footer_pos = "right",
	})
	vim.wo[win].number = true
	vim.wo[win].relativenumber = false
	vim.wo[win].cursorline = true

	local closed = false
	local function save_and_close()
		if closed then
			return
		end
		closed = true
		vim.cmd.stopinsert()
		save(root, list.from_lines(vim.api.nvim_buf_get_lines(buf, 0, -1, false), root))
		if vim.api.nvim_win_is_valid(win) then
			vim.api.nvim_win_close(win, true)
		end
	end

	vim.keymap.set("n", "q", save_and_close, { buffer = buf, desc = "Pin save the list and close it" })
	vim.keymap.set("n", "<Esc>", save_and_close, { buffer = buf, desc = "Pin save the list and close it" })
	vim.keymap.set("n", "<CR>", function()
		local path = vim.trim(vim.api.nvim_get_current_line())
		save_and_close()
		if path ~= "" then
			open_pin(root, vim.fs.normalize(path))
		end
	end, { buffer = buf, desc = "Pin open the file on this line" })

	vim.api.nvim_create_autocmd("BufLeave", {
		buffer = buf,
		once = true,
		callback = save_and_close,
	})
end

vim.keymap.set("n", "<leader>a", pin_current_file, { desc = "Pin the current file" })
vim.keymap.set("n", "<leader>A", edit_pins, { desc = "Pin list: reorder, unpin or open pinned files" })
for number = 1, KEYED_PINS do
	vim.keymap.set("n", "<leader>" .. number, function()
		go_to_pin(number)
	end, { desc = ("Pin go to pinned file %d"):format(number) })
end
