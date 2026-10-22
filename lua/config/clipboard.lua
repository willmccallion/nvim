--- System clipboard that works both at the desktop and over SSH from the Mac.
--- Copies go to the terminal as OSC 52, which tmux hands to whichever machine is
--- attached, and also to the Wayland clipboard when this nvim can reach it (an
--- nvim started at the desktop keeps WAYLAND_DISPLAY even after attaching remotely).
--- Pastes read the Wayland clipboard, or ask the terminal over OSC 52 without one.

local osc52 = require("vim.ui.clipboard.osc52")

local has_wayland = vim.env.WAYLAND_DISPLAY ~= nil
	and vim.fn.executable("wl-copy") == 1
	and vim.fn.executable("wl-paste") == 1

local function wayland_copy(argv)
	return function(lines)
		local job = vim.fn.jobstart(argv, { detach = true, cwd = "/" })
		if job > 0 then
			vim.fn.chansend(job, lines)
			vim.fn.chanclose(job, "stdin")
		end
	end
end

local function copy(reg, wayland_argv)
	local to_terminal = osc52.copy(reg)
	local to_wayland = has_wayland and wayland_copy(wayland_argv) or nil
	return function(lines, regtype)
		to_terminal(lines, regtype)
		if to_wayland then
			to_wayland(lines)
		end
	end
end

local paste
if has_wayland then
	paste = {
		["+"] = { "wl-paste", "--no-newline" },
		["*"] = { "wl-paste", "--no-newline", "--primary" },
	}
else
	paste = { ["+"] = osc52.paste("+"), ["*"] = osc52.paste("*") }
end

vim.g.clipboard = {
	name = "osc52+wayland",
	copy = {
		["+"] = copy("+", { "wl-copy", "--type", "text/plain" }),
		["*"] = copy("*", { "wl-copy", "--primary", "--type", "text/plain" }),
	},
	paste = paste,
}
