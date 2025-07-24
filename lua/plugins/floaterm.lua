local M = {}

-- Keep track of the previous window ID before focusing the terminal
local previous_win = nil

local state = {
  floating = {
    buf = -1,
    win = -1,
  }
}

-- (create_floating_window function remains the same)
local function create_floating_window(opts)
  opts = opts or {}

  local padding = opts.padding or 2 -- Uniform padding from top, bottom, left, right
  local border_width_total = 2 -- Assuming a 1-char border on each side (left/right, top/bottom)

  local max_content_width = vim.o.columns - 2 * padding - border_width_total
  local max_content_height = vim.o.lines - 2 * padding - border_width_total

  max_content_width = math.max(1, max_content_width)
  max_content_height = math.max(1, max_content_height)

  local desired_width = opts.width or math.floor(vim.o.columns * 0.5)
  local desired_height = opts.height or math.floor(vim.o.lines * 0.9)

  local width = math.min(desired_width, max_content_width)
  local height = math.min(desired_height, max_content_height)

  local target_center_col = math.floor(vim.o.columns * 3 / 4)
  local target_center_row = math.floor(vim.o.lines / 2) -- Same as before

  local ideal_col = target_center_col - math.floor(width / 2)
  local ideal_row = target_center_row - math.floor(height / 2)

  local min_col = padding
  local max_col = vim.o.columns - width - border_width_total - padding
  local min_row = padding
  local max_row = vim.o.lines - height - border_width_total - padding

  max_col = math.max(min_col, max_col)
  max_row = math.max(min_row, max_row)

  local col = math.max(min_col, math.min(ideal_col, max_col))
  local row = math.max(min_row, math.min(ideal_row, max_row))

  local buf = nil
  if opts.buf and vim.api.nvim_buf_is_valid(opts.buf) then -- Check opts.buf exists first
    buf = opts.buf
  else
    buf = vim.api.nvim_create_buf(false, true) -- Create a scratch buffer
  end

  -- Keep track of the buffer in the state IF it's newly created or wasn't tracked
  if state.floating.buf == -1 or not vim.api.nvim_buf_is_valid(state.floating.buf) then
      state.floating.buf = buf
  end

  -- Store the window we were in before opening/focusing the float
  previous_win = vim.api.nvim_get_current_win()

  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    col = col,
    row = row,
    style = "minimal",
    border = opts.border or "rounded",
    focusable = true, -- Ensure it's focusable
  }

  -- If window exists and is valid, just configure it (unhide/focus)
  -- Otherwise, open a new one
  local win
  if state.floating.win and vim.api.nvim_win_is_valid(state.floating.win) then
      vim.api.nvim_win_set_config(state.floating.win, win_config)
      win = state.floating.win
      vim.api.nvim_set_current_win(win) -- Explicitly focus
  else
      win = vim.api.nvim_open_win(buf, true, win_config) -- true means enter the window
      state.floating.win = win -- Store the new window ID
  end


  return { buf = state.floating.buf, win = win } -- Return the potentially persistent buffer
end


local toggle_terminal = function()
  if not vim.api.nvim_win_is_valid(state.floating.win) then
    -- Window doesn't exist or is invalid, create it
    local created = create_floating_window { buf = state.floating.buf }
    -- state.floating.win is updated inside create_floating_window now
    -- Check if the buffer is already a terminal
    if vim.bo[created.buf].buftype ~= "terminal" then
      vim.api.nvim_set_current_win(created.win) -- Ensure focus
      vim.cmd.terminal() -- Make it a terminal
      vim.schedule(function() vim.cmd('startinsert') end) -- Enter insert mode shortly after
    else
      -- Buffer is already a terminal, just ensure focus and insert mode
      vim.api.nvim_set_current_win(created.win)
      vim.schedule(function() vim.cmd('startinsert') end)
    end
  else
    -- Window is valid, toggle visibility/focus
    local current_win = vim.api.nvim_get_current_win()
    if current_win == state.floating.win then
      -- Currently in the float, hide it and go back to previous window
      vim.api.nvim_win_hide(state.floating.win)
      if previous_win and vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
      end
    else
      -- Not in the float, show and focus it
       -- Store the window we are leaving
       previous_win = vim.api.nvim_get_current_win()
       -- Show/Configure and focus the floating window
       local win_config = vim.api.nvim_win_get_config(state.floating.win)
       win_config.focusable = true -- Ensure focusable if hidden
       vim.api.nvim_win_set_config(state.floating.win, win_config) -- Re-apply config to ensure visibility
       vim.api.nvim_set_current_win(state.floating.win)
       vim.schedule(function() vim.cmd('startinsert') end) -- Enter insert mode
    end
  end
end

-- NEW function to specifically focus the terminal window
local function focus_floating_terminal()
  if state.floating.win and vim.api.nvim_win_is_valid(state.floating.win) then
    -- Store the window we are leaving
    previous_win = vim.api.nvim_get_current_win()
    -- Set focus to the floating terminal window
    vim.api.nvim_set_current_win(state.floating.win)
    -- Optionally enter terminal insert mode
    local buf_id = vim.api.nvim_win_get_buf(state.floating.win)
    if vim.bo[buf_id].buftype == 'terminal' then
       vim.schedule(function() -- Use schedule for safety after window switch
           vim.cmd('startinsert')
       end)
    end
  else
    -- Optional: Notify user if window not found
    print("Floating terminal window not found or invalid.")
    -- Maybe call toggle_terminal() here to open it? Depends on desired behavior.
    -- toggle_terminal() -- Uncomment this line if you want <leader>t<Tab> to open it if closed.
  end
end

-- NEW function to switch back to the *previous* window without hiding the float
local function focus_previous_window()
    if previous_win and vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
    else
        -- Fallback if previous_win is invalid (e.g., was closed)
        vim.cmd('wincmd p') -- Use standard vim command to go to previous window
    end
end


function M.setup()
  vim.api.nvim_create_user_command("Floaterminal", toggle_terminal, {})
  -- This keymap now toggles visibility/focus
  vim.keymap.set({"n","t"}, "<leader>tt", "<cmd>Floaterminal<CR>", { desc = "Toggle Terminal Show/Hide"})

  -- Keymap: In Terminal Mode -> Switch focus OUT to previous window
  vim.keymap.set("t", "<leader>tn", function() focus_previous_window() end, { desc = "Focus previous window (keep terminal)" })

  -- Keymap: In Normal Mode -> Switch focus IN to the floating terminal
  vim.keymap.set("n", "<leader>tn", function() focus_floating_terminal() end, { desc = "Focus floating terminal" })

  -- Keymap: Close the floating terminal completely (FIXED)
  vim.keymap.set("t", "<leader>tk", function() M.close_terminal() end, { desc = "Close floating terminal" })
end

-- (The rest of your code remains the same)

-- Add a function to properly close and clean up state
function M.close_terminal()
    if state.floating.win and vim.api.nvim_win_is_valid(state.floating.win) then
        local buf_id = state.floating.buf
        vim.api.nvim_win_close(state.floating.win, true) -- Force close the window
        -- Only wipe if it's a scratch/terminal buffer we manage
        if buf_id and vim.api.nvim_buf_is_valid(buf_id) and vim.bo[buf_id].buftype == 'terminal' then
             vim.api.nvim_buf_delete(buf_id, { force = true })
        end
    end
    -- Reset state
    state.floating.win = -1
    state.floating.buf = -1
    -- Try to focus previous window if known
    if previous_win and vim.api.nvim_win_is_valid(previous_win) then
        vim.api.nvim_set_current_win(previous_win)
    end
    previous_win = nil
end


-- Don't forget to return M if this is a module
return M

-- Make sure your file is saved as, e.g., lua/my-floaterm.lua
-- And call require('my-floaterm').setup() in your init.lua
