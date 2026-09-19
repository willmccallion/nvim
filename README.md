# Neovim Configuration

My Neovim config for C, C++, Rust, Python, Lua, and Nix.
Everything is in Lua and uses the built-in `vim.pack` plugin system. Plugin versions are pinned in `nvim-pack-lock.json`.

## Getting Started

Requires **Neovim 0.13+**, a **Nerd Font**, **ripgrep** (for grep/search), and a **C compiler** (for treesitter parsers).

For LSP support, install the language servers you need: `clangd`, `rust-analyzer`, `lua-language-server`, `pyright`, `nixd`.
Same for formatters: `clang-format`, `rustfmt`, `stylua`, `black`/`isort`, `nixfmt`.
Debugging needs `lldb-dap` (ships with LLDB).
The config picks them up automatically if they're on your PATH.

## How It's Organized

```
init.lua             Loads config first, then plugins by category
lsp/                 One file per language server (clangd, rust_analyzer, lua_ls, pyright, nixd)
lua/
  config/            Options, keymaps, globals, autocommands, terminal toggles
  plugins/
    ui/              Colorscheme, file explorer (oil), diagnostics display, sticky context
    coding/          Completion, formatting, treesitter, autopairs, snippets
      build/         Build runner (detection, per-project storage, runner)
    debug/           Debugger (nvim-dap + nvim-dap-view)
    editor/          Navigation, search, git, surround, multi-cursor, undo tree
    lsp/             LSP enablement and keymaps
```

To add a language server, drop a `lsp/<name>.lua` returning its config and add the name to `vim.lsp.enable` in `lua/plugins/lsp/init.lua`.
To add a treesitter language, add the parser name to the `parsers` list in `lua/plugins/coding/treesitter.lua`.

## What's In Here

**LSP**: Native `vim.lsp.config`/`vim.lsp.enable`, with server configs in the runtime `lsp/` directory. Completion is handled by nvim-cmp with LSP, snippet, path, and buffer sources.

**Treesitter**: Syntax highlighting and text objects (`af`/`if`, `ac`/`ic`, `aa`/`ia`, `ai`/`ii`, `al`/`il`) with `]f`/`[f`-style motions. Incremental selection is built into Neovim: in visual mode `an` grows the selection to the parent node and `in` shrinks it. nvim-treesitter-context pins the enclosing function/loop to the top of the window; `[x` jumps to it.

**Build**: `<leader>mb` builds the project in the background and loads compiler errors into quickfix. The build system is detected from the current file upward (stopping at the git root):
- `Cargo.toml` runs `cargo build` from the outermost `Cargo.toml` (the workspace root).
- `CMakeLists.txt` configures a Debug build (so the debugger works) into `build/` from the outermost `CMakeLists.txt`, exporting `compile_commands.json` for clangd.
- `Makefile` runs `make` from the nearest `Makefile`.
- When several appear in one directory, Cargo beats CMake beats Make.

`<leader>mp` picks another detected command or lets you type your own. The choice is remembered per project in `stdpath("data")/build-commands.json`.

**Debugging**: nvim-dap with `lldb-dap` for C, C++, and Rust, and nvim-dap-view as the UI (opens and closes with the session). `<F5>` starts a session and prompts for the executable, defaulting to `target/debug/` or `build/`. Rust sessions load rustc's LLDB formatters so `Vec`, `String`, etc. display readably.

**Formatting**: Format-on-save via conform.nvim. Each language has its own formatter configured. Lua style is set by `.stylua.toml`.

**Search**: Telescope for finding files, grepping, searching buffers/diagnostics/help/keymaps/TODOs/symbols. There's also a project-wide search-and-replace built on top of Telescope and quickfix.

**File Explorer**: Oil.nvim lets you edit your filesystem like a regular buffer.

**Git**: Gitsigns shows changed/added/deleted lines in the sign column with keymaps for staging, resetting, and previewing hunks.

**Diagnostics**: Trouble.nvim gives you a list view of diagnostics and symbols. `<leader>l` toggles Neovim's native multiline diagnostics under your code.

**Navigation**: Flash.nvim for label-based jumping (`s`) and multi-line `f`/`t`/`F`/`T` motions, accelerated j/k so holding the key speeds up over time, and centered scrolling/search.

**Editing**: Built-in `gc`/`gcc` commenting, nvim-surround for manipulating pairs, vim-visual-multi for multi-cursor (`<C-n>` selects the word under the cursor; its other mappings start with `\\`), autopairs, and Neovim's bundled undo tree.

**Terminals**: Toggleable splits that keep their session when hidden: a bottom shell, a right shell, and a Python REPL.

**Theme**: Vague with transparent background. Tokyonight, Nightfox, and Rose Pine are also installed if you want to swap.

## Keymap Prefixes

Leader is **Space**. Every mapping has a description, so `<leader>sk` searches them all; descriptions start with the category below.

| Prefix | Category |
|---|---|
| `<leader>s` | Search (files, grep, help, symbols, marks, ...) |
| `<leader>w` | Window (split, move, swap, maximize) |
| `<leader>b` | Buffer |
| `<leader>t` | Terminal (`tt` bottom, `tv` right, `tp` Python) |
| `<leader>m` | Build (`mb` build, `mp` pick, `mo` output, `mk` stop) |
| `<leader>D` | Debug (`Db` breakpoint, `Du` view, `Dq` stop, ...); `<F5>`/`<F10>`/`<F11>`/`<F12>` continue/step |
| `<leader>d` | Diagnostics and symbols (Trouble) |
| `<leader>h` | Git hunks |
| `<leader>q` | Quickfix list |
| `<leader>x` | Lua (execute line/selection, source file) |
| `<leader>r` | Replace / rename |
| `g`         | LSP go-to (`gd`, `gr`, `gi`, `gt`, `gD`) |

## Notes

- Format-on-save can be disabled globally (`vim.g.autoformat = false`) or per-buffer (`vim.b.autoformat = false`).
- Supports local project config via `.nvim.lua` / `.exrc` files.
- Run `:LspInfo` (or `:checkhealth vim.lsp`) to see configured servers and attached clients.
- Run `:Update` to update all plugins, then commit the updated `nvim-pack-lock.json`.
