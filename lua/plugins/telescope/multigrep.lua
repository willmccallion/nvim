local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local make_entry = require "telescope.make_entry"
local conf = require "telescope.config".values

local M = {}

local function get_visual_selection_or_cword()
  local mode = vim.fn.mode()
  if mode == 'v' or mode == 'V' then
    local a = vim.api.nvim_buf_get_mark(0, '<')
    local b = vim.api.nvim_buf_get_mark(0, '>')
    local lines = vim.api.nvim_buf_get_text(0, a[1] - 1, a[2], b[1] - 1, b[2], {})
    return table.concat(lines, '\n')
  else
    return vim.fn.expand("<cword>")
  end
end

local live_multigrep = function(opts)
  opts = opts or {}
  opts.cwd = opts.cwd or vim.uv.cwd()

  local finder = finders.new_async_job {
    command_generator = function(prompt)
      if not prompt or prompt == "" then
        return nil
      end

      local pieces = vim.split(prompt, "  ")
      local args = { "rg" }
      if pieces[1] then
        table.insert(args, "-e")
        table.insert(args, pieces[1])
      end

      if pieces[2] then
        table.insert(args, "-g")
        table.insert(args, pieces[2])
      end

      ---@diagnostic disable-next-line: deprecated
      return vim.tbl_flatten {
        args,
        { "--color=never", "--no-heading", "--with-filename", "--line-number", "--column", "--smart-case" },
      }
    end,
    entry_maker = make_entry.gen_from_vimgrep(opts),
    cwd = opts.cwd,
  }

  pickers.new(opts, {
    debounce = 100,
    prompt_title = "Multi Grep",
    finder = finder,
    previewer = conf.grep_previewer(opts),
    sorter = require("telescope.sorters").empty(),
  }):find()
end

local function live_multigrep_for_word()
  local search_term = get_visual_selection_or_cword()
  search_term = vim.fn.escape(search_term, '.*^$[]%')
  live_multigrep({ default_text = search_term })
end

M.setup = function()
  vim.keymap.set("n", "<leader>sg", live_multigrep, { desc = "Telescope Live Multi Grep" })

  vim.keymap.set("n", "<leader>sw", live_multigrep_for_word, { desc = "Telescope Live Grep for Word" })
  vim.keymap.set("v", "<leader>sw", live_multigrep_for_word, { desc = "Telescope Live Grep for Selection" })
end

return M
