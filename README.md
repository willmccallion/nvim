# Neovim Configuration

My Neovim config for C, C++, Rust, Python, and Lua.
Everything is in Lua and uses the built-in `vim.pack` plugin system that shipped in Neovim 0.12.

## Getting Started

Requires **Neovim 0.12.0+**, a **Nerd Font**, **ripgrep** (for grep/search), and a **C compiler** (for treesitter parsers).

For LSP support, install the language servers you need: `clangd`, `rust-analyzer`, `lua-language-server`, `pyright`.
Same for formatters: `clang-format`, `rustfmt`, `stylua`, `black`/`isort`.
The config will pick them up automatically if they're on your PATH.

## How It's Organized

```
lua/
  config/            Options, keymaps, globals, autocommands
  plugins/
    ui/              Colorscheme, file explorer (oil), diagnostics display
    coding/          Completion, formatting, treesitter, autopairs, snippets
    editor/          Navigation, search, git, surround, comments, multi-cursor
    lsp/             LSP client setup
      servers/       One file per language server (clangd, rust_analyzer, lua_ls, pyright)
```

Everything is loaded from `init.lua` in a order of config first, then plugins by category.

## What's In Here

**LSP**: Native LSP client with auto-start per filetype. Each server has its own config file under `lsp/servers/` so it's easy to add or tweak one without touching the rest. Completion is handled by nvim-cmp with LSP, snippet, path, and buffer sources.

**Treesitter**: Syntax highlighting, indentation, incremental selection, and text objects. You get motions for jumping between functions, classes, and arguments, plus selection of those same structures.

**Formatting**: Format-on-save via conform.nvim. Each language has its own formatter configured. You can disable it per-buffer if needed.

**Search**: Telescope for finding files, grepping, searching buffers/diagnostics/help/keymaps/TODOs. There's also a project-wide search-and-replace built on top of Telescope and quickfix.

**File Explorer**: Oil.nvim lets you edit your filesystem like a regular buffer. Way nicer than a tree sidebar.

**Git**: Gitsigns shows changed/added/deleted lines in the sign column with keymaps for staging, resetting, and previewing hunks.

**Diagnostics**: Trouble.nvim gives you a nice list view of diagnostics and symbols. lsp_lines.nvim can render multiline diagnostics inline under your code (togglable).

**Navigation**: Flash.nvim for label-based jumping, accelerated j/k so holding the key speeds up over time, and centered scrolling/search.

**Editing**: Comment.nvim for toggling comments, nvim-surround for manipulating pairs, vim-visual-multi for multi-cursor, and autopairs for automatic bracket closing.

**Theme**: Tokyonight (night) with transparent background. Nightfox and Rose Pine are also installed if you want to swap.

## Notes

- Leader key is **Space**.
- All keymaps have descriptions -- use `:Telescope keymaps` (or `<leader>sk`) to search them.
- Format-on-save can be disabled globally (`vim.g.autoformat = false`) or per-buffer (`vim.b.autoformat = false`).
- Supports local project config via `.exrc` files.
- Run `:LspInfo` to see which servers are attached to the current buffer.
- Run `:Update` to update all plugins.
