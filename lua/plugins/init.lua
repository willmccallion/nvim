return {
  -- Core Functionality & UI
  require('plugins.undotree'),
  require('plugins.lastplace'),
  require('plugins.which-key'),
  require('plugins.markdown'),
  require('plugins.flash'),

  -- Filetype/Syntax Enhancement
  require('plugins.treesitter'),
  require('plugins.rainbow-delimiters'),
  require('plugins.vim-sleuth'), -- Auto-detect indent settings

  -- Git Integration
  require('plugins.gitsigns'),

  -- LSP, Formatting, Completion
  require('plugins.lsp'),
  require('plugins.conform'),
  require('plugins.completion'),

  -- Utilities & Tools
  require('plugins.telescope'),
  require('plugins.todo-comments'),
  require('plugins.mini'), -- For mini.ai and mini.surround
  require('plugins.vim-fugitive'),
  require('plugins.oil'),

  -- Lua Development Helpers (Optional)
  require('plugins.lazydev'),

  -- Colorschemes (Keep these towards the end, especially the def:ault)
  require('plugins.colorschemes'),
  require('plugins.todo-float').setup({
    target_file = "todo.md",
    global_file = "~/.config/nvim/lua/plugins/todo-float/todo.md",
  }),
}
