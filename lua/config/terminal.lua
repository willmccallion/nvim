--- @module config.terminal
--- @brief Toggleable terminal splits.
--- Each toggle keeps its own terminal buffer, so hiding a terminal preserves
--- its session. An exited terminal is replaced by a fresh one on next open.

local function is_running(buf)
	return vim.fn.jobwait({ vim.bo[buf].channel }, 0)[1] == -1
end

local function hide(win)
	if #vim.api.nvim_tabpage_list_wins(0) == 1 then
		vim.notify("Terminal is the only window; not hiding it", vim.log.levels.WARN)
		return
	end
	vim.api.nvim_win_close(win, false)
end

--- Returns a function that shows or hides a terminal opened with `split_cmd`.
--- @param split_cmd string Ex command that opens the window, e.g. "botright 15split"
--- @param program? string command to run instead of 'shell'
local function terminal_toggle(split_cmd, program)
	local buf = nil
	return function()
		if buf and vim.api.nvim_buf_is_valid(buf) then
			local win = vim.fn.win_findbuf(buf)[1]
			if win then
				hide(win)
				return
			end
			if not is_running(buf) then
				vim.api.nvim_buf_delete(buf, { force = true })
				buf = nil
			end
		end

		vim.cmd(split_cmd)
		if buf then
			vim.api.nvim_set_current_buf(buf)
		else
			vim.cmd.terminal(program)
			buf = vim.api.nvim_get_current_buf()
		end
		vim.cmd.startinsert()
	end
end

vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { desc = "Terminal exit to normal mode" })

vim.keymap.set("n", "<leader>tt", terminal_toggle("botright 15split"), { desc = "Terminal toggle bottom split" })
vim.keymap.set("n", "<leader>tv", terminal_toggle("botright vsplit"), { desc = "Terminal toggle right split" })
vim.keymap.set(
	"n",
	"<leader>tp",
	terminal_toggle("botright 12split", "python3"),
	{ desc = "Terminal toggle Python REPL split" }
)
