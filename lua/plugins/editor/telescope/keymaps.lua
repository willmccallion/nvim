--- Keymap picker grouped by the domain each key sequence belongs to.
--- Telescope's own keymaps picker lists a row per mode, skips operator-pending
--- maps and falls back to the rhs for unlabelled ones, so the config's own
--- bindings are buried among hundreds of internal maps. This one derives the
--- domain from the key sequence, merges the modes of otherwise identical
--- mappings, and orders the list by domain so it reads as the grammar:
--- typing "git" narrows to the git keys, and an empty prompt is already grouped.

--- The second key after <leader> names the domain, as in the README's table.
local LEADER_DOMAINS = {
	b = "Buffer",
	c = "Code",
	d = "Debug",
	e = "File",
	E = "File",
	g = "Git",
	L = "Lua",
	m = "Build",
	o = "Option",
	p = "Clipboard",
	P = "Clipboard",
	q = "Quickfix",
	r = "Replace",
	s = "Search",
	t = "Terminal",
	u = "Undo",
	v = "Multi-cursor",
	w = "Window",
	x = "Problems",
	y = "Clipboard",
	[" "] = "Search",
}

--- Keys whose domain cannot be read off a leader, bracket or textobject shape.
--- Spelled as nvim_get_keymap returns them: it upper-cases the letter in a
--- control key and writes "<" as <lt>.
local KEY_DOMAINS = {
	["&"] = "Editing",
	["*"] = "Motion",
	["#"] = "Motion",
	["-"] = "File",
	["<lt>"] = "Editing",
	[">"] = "Editing",
	["<C-Down>"] = "Window",
	["<C-Left>"] = "Window",
	["<C-Right>"] = "Window",
	["<C-Up>"] = "Window",
	["<C-D>"] = "Motion",
	["<C-U>"] = "Motion",
	["<C-N>"] = "Multi-cursor",
	["<C-S>"] = "LSP",
	["<Down>"] = "Motion",
	["<Up>"] = "Motion",
	["<Esc><Esc>"] = "Terminal",
	["<M-S-Down>"] = "Editing",
	["<M-S-Up>"] = "Editing",
	["<S-Tab>"] = "Editing",
	["<Tab>"] = "Editing",
	["<C-G>s"] = "Surround",
	["<C-G>S"] = "Surround",
	J = "Editing",
	K = "LSP",
	N = "Motion",
	S = "Surround",
	Y = "Editing",
	cS = "Surround",
	cs = "Surround",
	dS = "Surround",
	ds = "Surround",
	gD = "LSP",
	gK = "LSP",
	gO = "LSP",
	gS = "Surround",
	gc = "Editing",
	gcc = "Editing",
	gd = "LSP",
	gr = "LSP",
	gra = "LSP",
	gri = "LSP",
	grn = "LSP",
	grr = "LSP",
	grt = "LSP",
	grx = "LSP",
	j = "Motion",
	k = "Motion",
	n = "Motion",
	p = "Editing",
	s = "Motion",
	yS = "Surround",
	ySS = "Surround",
	ys = "Surround",
	yss = "Surround",
}

--- Keys that mean something different in the mode they are mapped in, keyed by
--- the exact mode set: <C-U> scrolls in normal mode but deletes while inserting.
local MODE_DOMAINS = {
	["<C-U>"] = { i = "Editing" },
	["<C-W>"] = { i = "Editing" },
}

local MODES = { "n", "x", "o", "i", "s", "c", "t" }

---@class KeymapRow
---@field domain string
---@field lhs string as it would be written in the config
---@field keys string as nvim stores it, fed back when the entry is selected
---@field modes string one letter per mode the mapping exists in
---@field desc string
---@field buffer_local boolean

--- nvim_get_keymap already writes special keys as <C-Up>, so only the leader
--- (a literal space here) and stray whitespace need spelling out.
---@param keys string
---@return string
local function display_lhs(keys)
	local leader = vim.g.mapleader
	local prefix = ""
	local rest = keys
	while leader and leader ~= "" and rest:sub(1, #leader) == leader do
		prefix = prefix .. "<leader>"
		rest = rest:sub(#leader + 1)
	end
	return prefix .. rest:gsub(" ", "<Space>"):gsub("\t", "<Tab>")
end

---@param keys string as nvim stores it
---@param modes string
---@return string
local function domain_of(keys, modes)
	local by_mode = MODE_DOMAINS[keys]
	if by_mode and by_mode[modes] then
		return by_mode[modes]
	end
	local explicit = KEY_DOMAINS[keys]
	if explicit then
		return explicit
	end

	local leader = vim.g.mapleader
	if leader and leader ~= "" and keys:sub(1, #leader) == leader then
		return LEADER_DOMAINS[keys:sub(#leader + 1, #leader + 1)] or "Other"
	end
	-- Only where a bracket starts a motion: insert mode maps them to pair keys.
	if keys:match("^[%[%]]") and modes:match("[nxo]") then
		return "Motion"
	end
	-- a/i plus one key, selecting or operating on a region: af, ic, an, ...
	if keys:match("^[ai].$") and modes:match("[xo]") then
		return "Textobject"
	end
	if keys:match("^<[cC]%-[wW]>") then
		return "Window"
	end
	-- grug-far's buffer keys, which sit behind <localleader>.
	if keys:sub(1, 1) == "," then
		return "Replace"
	end
	return "Other"
end

---@param map vim.api.keyset.get_keymap
---@param show_unlabelled boolean
---@return string? nil when the mapping has no label and unlabelled ones are hidden
local function description_of(map, show_unlabelled)
	if map.desc and map.desc ~= "" then
		return (map.desc:gsub("%s+", " "))
	end
	if not show_unlabelled then
		return nil
	end
	if map.rhs and map.rhs ~= "" then
		return (map.rhs:gsub("%s+", " "))
	end
	if map.callback then
		local info = debug.getinfo(map.callback, "S")
		return ("%s:%d"):format(vim.fn.fnamemodify(info.short_src, ":~:."), info.linedefined)
	end
	return "(unlabelled)"
end

--- Global and current-buffer mappings, one row per mapping rather than per mode.
---@param show_unlabelled boolean
---@return KeymapRow[] sorted by domain, then by key sequence
local function collect(show_unlabelled)
	local seen = {}
	local rows = {}

	for _, mode in ipairs(MODES) do
		local maps = vim.api.nvim_get_keymap(mode)
		vim.list_extend(maps, vim.api.nvim_buf_get_keymap(0, mode))

		for _, map in ipairs(maps) do
			local desc = description_of(map, show_unlabelled)
			local internal = map.lhs:find("<Plug>", 1, true) or map.lhs:find("<SNR>", 1, true)
			if desc and not (internal and not show_unlabelled) then
				local buffer_local = map.buffer ~= 0
				local key = table.concat({ map.lhs, desc, tostring(buffer_local) }, "\0")
				if seen[key] then
					-- The same mapping in another mode: widen that row instead of repeating it.
					seen[key].modes = seen[key].modes .. mode
				else
					local row = {
						lhs = display_lhs(map.lhs),
						keys = map.lhs,
						desc = desc,
						modes = mode,
						buffer_local = buffer_local,
					}
					seen[key] = row
					table.insert(rows, row)
				end
			end
		end
	end

	for _, row in ipairs(rows) do
		row.domain = domain_of(row.keys, row.modes)
	end

	table.sort(rows, function(a, b)
		if a.domain ~= b.domain then
			return a.domain < b.domain
		end
		if a.lhs ~= b.lhs then
			return a.lhs < b.lhs
		end
		return a.desc < b.desc
	end)
	return rows
end

---@param rows KeymapRow[]
---@param field string
---@param limit integer
---@return integer
local function column_width(rows, field, limit)
	local width = 0
	for _, row in ipairs(rows) do
		width = math.max(width, vim.fn.strdisplaywidth(row[field]))
	end
	return math.min(width, limit)
end

local M = {}

---@param opts? {show_unlabelled?: boolean}
function M.pick(opts)
	opts = opts or {}
	local pickers = require("telescope.pickers")
	local finders = require("telescope.finders")
	local conf = require("telescope.config").values
	local actions = require("telescope.actions")
	local action_state = require("telescope.actions.state")
	local entry_display = require("telescope.pickers.entry_display")

	local rows = collect(opts.show_unlabelled or false)

	local displayer = entry_display.create({
		separator = " ▏",
		items = {
			{ width = column_width(rows, "domain", 12) },
			{ width = column_width(rows, "lhs", 20) },
			{ width = column_width(rows, "modes", 7) + 1 },
			{ remaining = true },
		},
	})

	---@param entry {value: KeymapRow}
	local function make_display(entry)
		local row = entry.value
		return displayer({
			{ row.domain, "TelescopeResultsIdentifier" },
			{ row.lhs, "TelescopeResultsConstant" },
			{ row.modes .. (row.buffer_local and "@" or ""), "TelescopeResultsComment" },
			row.desc,
		})
	end

	pickers
		.new(opts, {
			prompt_title = opts.show_unlabelled and "Key Maps (including unlabelled)" or "Key Maps",
			finder = finders.new_table({
				results = rows,
				---@param row KeymapRow
				entry_maker = function(row)
					return {
						value = row,
						-- Domain first, so typing one narrows the list to that group.
						ordinal = table.concat({ row.domain, row.lhs, row.modes, row.desc }, " "),
						display = make_display,
					}
				end,
			}),
			sorter = conf.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr)
				actions.select_default:replace(function()
					local selection = action_state.get_selected_entry()
					actions.close(prompt_bufnr)
					if not selection then
						return
					end
					local keys = vim.api.nvim_replace_termcodes(selection.value.keys, true, false, true)
					vim.api.nvim_feedkeys(keys, "t", false)
				end)
				return true
			end,
		})
		:find()
end

return M
