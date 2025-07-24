-- lua/plugins/todo-comments.lua
return {
  'folke/todo-comments.nvim',
  event = 'BufReadPost', -- Load after buffer read
  dependencies = { 'nvim-lua/plenary.nvim' },
  opts = {
    signs = true, -- Show signs in the sign column
    sign_priority = 8, -- Adjust priority if needed
    keywords = {
      FIX = { icon = " ", color = "error", alt = { "FIXME", "BUG", "ISSUE", "ERROR" } },
      TODO = { icon = " ", color = "info", alt = { "TASK" } },
      HACK = { icon = " ", color = "warning" },
      WARN = { icon = " ", color = "warning", alt = { "WARNING", "ALERT" } },
      PERF = { icon = "󰅒 ", color = "hint", alt = { "PERFORMANCE", "OPTIMIZE" } },
      NOTE = { icon = "󰎞 ", color = "hint", alt = { "INFO", "COMMENT" } },
      TEST = { icon = "󰙨 ", color = "test", alt = { "TESTING" } },
      SECTION = { icon = "  ", color = "section", alt = { "GROUP"}},
    }, --
    merge_keywords = true, -- Merge custom keywords with defaults
    highlight = {
      multiline = true, -- Highlight multiline TODOs
      multiline_pattern = "^ NB", -- Example pattern for multiline notes
      multiline_context = 10,
      before = "", -- "fg" or "bg" or empty
      keyword = "wide", -- "fg", "bg", "wide", "wide_bg", "italic"
      after = "fg", -- "fg" or "bg" or empty
      pattern = [[.*<(KEYWORDS)\s*:]], -- Pattern to detect TODOs like 'TODO:'
      comments_only = true, -- Search only in comments
      max_line_len = 400,
      exclude = {}, -- List of file types to exclude
    },
    colors = { -- Custom color definitions
      error = { "#DC2626" },
      warning = { "#FBBF24" },
      info = { "#2563EB" },
      hint = { "#10B981" },
      default = { "#7C3AED" },
      test = { "#FF8800" }, -- Custom color for TEST
      section = { "#8800aa"},
    },
    search = {
      command = "rg",
      args = {
        "--color=never",
        "--no-heading",
        "--with-filename",
        "--line-number",
        "--column",
      },
      pattern = [[\b(KEYWORDS):]], -- Regex pattern for finding TODOs
    },
  },
  -- Optional: Add keymaps for telescope integration
  keys = {
     { "]t", function() require("todo-comments").jump_next() end, desc = "Next Todo Comment" },
     { "[t", function() require("todo-comments").jump_prev() end, desc = "Previous Todo Comment" },
     { "<leader>st", "<cmd>TodoTelescope<cr>", desc = "[S]earch [T]odo comments" },
  }
}
