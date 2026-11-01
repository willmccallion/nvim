--- Notes: the whole config on a temporary vault, with stand-ins for the programs that
--- would reach the desktop's Obsidian or the Mac.

local h = require("helpers")

local tests = {}

---@param tools table<string, string> each program's name and its shell script
---@return string bin the folder holding them
local function stub(tools)
	local bin = h.temp_dir()
	for tool, script in pairs(tools) do
		vim.fn.writefile({ "#!/bin/sh", script }, bin .. "/" .. tool)
		vim.fn.setfperm(bin .. "/" .. tool, "rwxr-xr-x")
	end
	return bin
end

--- A home with a vault holding a.md, and an environment that isn't over SSH or in tmux
--- whatever these tests were started from.
---@param note? string[] a.md's lines
---@return string home
local function vault(note)
	local home = h.temp_dir()
	vim.fn.mkdir(home .. "/notes", "p")
	vim.fn.writefile(note or { "# A" }, home .. "/notes/a.md")
	vim.env.TMUX = nil
	vim.env.SSH_CONNECTION = nil
	return home
end

---@param home string
---@param tools table<string, string>
---@param env? table<string, string>
---@return string[] the lines the stand-ins logged to $home/opened
local function press_open(home, tools, env)
	local probe = {
		"vim.fn.maparg(vim.keycode('<leader>no'), 'n', false, true).callback()",
		"vim.wait(5000, function() return vim.fn.filereadable(vim.env.HOME .. '/opened') == 1 end, 20)",
	}
	local full_env = vim.tbl_extend("force", {
		HOME = home,
		PATH = stub(tools) .. ":" .. vim.env.PATH,
	}, env or {})
	local result = h.start_config(probe, home .. "/notes/a.md", full_env)
	h.assert_equal(result.stderr, "", "errors")
	if vim.fn.filereadable(home .. "/opened") == 0 then
		return {}
	end
	return vim.fn.readfile(home .. "/opened")
end

local LOG_SSH = 'echo "ssh $*" >> "$HOME/opened"'
local LOG_XDG_OPEN = 'echo "xdg-open $*" >> "$HOME/opened"'
local NOTE_URI = "obsidian://open?vault=notes&file=a.md"

function tests.at_the_desktop_a_note_opens_in_its_own_obsidian()
	local home = vault()

	local opened = press_open(home, { ssh = LOG_SSH, ["xdg-open"] = LOG_XDG_OPEN })

	h.assert_equal(opened, { "xdg-open " .. NOTE_URI }, "what ran")
end

function tests.over_ssh_a_note_opens_on_the_mac()
	local home = vault()

	local opened = press_open(
		home,
		{ ssh = LOG_SSH, ["xdg-open"] = LOG_XDG_OPEN },
		{ SSH_CONNECTION = "1.2.3.4 1 5.6.7.8 22" }
	)

	h.assert_equal(opened, { ("ssh -o BatchMode=yes mac open '%s'"):format(NOTE_URI) }, "what ran")
end

function tests.a_tmux_window_started_at_the_desktop_still_opens_on_the_mac_once_attached_from_it()
	local home = vault()

	local opened = press_open(home, {
		ssh = LOG_SSH,
		["xdg-open"] = LOG_XDG_OPEN,
		tmux = "echo SSH_CONNECTION=1.2.3.4",
	}, { TMUX = "/tmp/tmux,1,0" })

	h.assert_equal(#opened, 1, "runs once")
	h.assert_equal(vim.startswith(opened[1], "ssh "), true, "goes to the Mac")
end

function tests.a_tmux_window_started_over_ssh_opens_here_once_the_session_is_back_at_the_desktop()
	local home = vault()

	local opened = press_open(home, {
		ssh = LOG_SSH,
		["xdg-open"] = LOG_XDG_OPEN,
		tmux = "echo -SSH_CONNECTION",
	}, { TMUX = "/tmp/tmux,1,0", SSH_CONNECTION = "1.2.3.4 1 5.6.7.8 22" })

	h.assert_equal(opened, { "xdg-open " .. NOTE_URI }, "what ran")
end

function tests.a_failed_open_on_the_mac_is_reported()
	local home = vault()
	local bin = stub({ ssh = "echo no route to mac >&2; exit 255" })

	local result = h.start_config({
		"local seen = {}",
		"vim.notify = function(message) table.insert(seen, message) end",
		"vim.fn.maparg(vim.keycode('<leader>no'), 'n', false, true).callback()",
		"vim.wait(5000, function() return #seen > 0 end, 20)",
		"io.write(table.concat(seen))",
	}, home .. "/notes/a.md", { HOME = home, PATH = bin .. ":" .. vim.env.PATH, SSH_CONNECTION = "1 2 3 4" })

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "Opening on the Mac failed: no route to mac", "message")
end

function tests.opening_saves_the_note_first()
	local home = vault()
	local bin = stub({ ["xdg-open"] = 'cp "$HOME/notes/a.md" "$HOME/opened"' })

	h.start_config({
		"vim.api.nvim_buf_set_lines(0, 0, -1, false, { '# Edited' })",
		"vim.fn.maparg(vim.keycode('<leader>no'), 'n', false, true).callback()",
		"vim.wait(5000, function() return vim.fn.filereadable(vim.env.HOME .. '/opened') == 1 end, 20)",
	}, home .. "/notes/a.md", { HOME = home, PATH = bin .. ":" .. vim.env.PATH })

	h.assert_equal(vim.fn.readfile(home .. "/opened"), { "# Edited" }, "what Obsidian was given")
end

function tests.saving_a_note_leaves_its_front_matter_alone()
	local note = { "---", "zebra: 1", "tags: [b, a]", "---", "", "# A" }
	local home = vault(note)

	local result = h.start_config({ "vim.cmd('silent write!')" }, home .. "/notes/a.md", { HOME = home })

	h.assert_equal(result.stderr, "", "errors")
	h.assert_equal(vim.fn.readfile(home .. "/notes/a.md"), note, "the note")
end

function tests.saving_a_note_without_front_matter_adds_none()
	local home = vault()

	h.start_config({ "vim.cmd('silent write!')" }, home .. "/notes/a.md", { HOME = home })

	h.assert_equal(vim.fn.readfile(home .. "/notes/a.md"), { "# A" }, "the note")
end

function tests.obsidian_is_set_up_by_a_file_in_the_vault_but_not_by_one_outside_it()
	local home = vault()
	local outside = h.temp_dir() .. "/b.md"
	vim.fn.writefile({ "# B" }, outside)
	local probe = { "io.write(tostring(package.loaded.obsidian ~= nil))" }

	local inside_result = h.start_config(probe, home .. "/notes/a.md", { HOME = home })
	local outside_result = h.start_config(probe, outside, { HOME = home })

	h.assert_equal(inside_result.stdout .. inside_result.stderr, "true", "in the vault")
	h.assert_equal(outside_result.stdout .. outside_result.stderr, "false", "outside it")
end

function tests.without_a_vault_only_the_drawing_key_exists()
	local home = h.temp_dir()

	local result = h.start_config({
		"for _, key in ipairs({ 'no', 'nb', 'nl', 'nr' }) do",
		"  io.write(key, '=', vim.fn.maparg(vim.keycode('<leader>' .. key), 'n') ~= '' and 'y' or 'n', ' ')",
		"end",
	}, nil, { HOME = home })

	h.assert_equal(vim.trim(result.stdout .. result.stderr), "no=n nb=n nl=n nr=y", "keys")
end

function tests.math_is_drawn_only_with_both_of_its_tools()
	local probe = { "io.write(tostring(Snacks.config.image.enabled))" }
	local home = h.temp_dir()
	local both = stub({ magick = "", pdflatex = "" })
	local one = stub({ magick = "" })

	local with_both = h.start_config(probe, nil, { HOME = home, PATH = both })
	local with_one = h.start_config(probe, nil, { HOME = home, PATH = one })

	h.assert_equal(with_both.stdout:match("%a+$"), "true", "both")
	h.assert_equal(with_one.stdout:match("%a+$"), "false", "only magick")
end

return tests
