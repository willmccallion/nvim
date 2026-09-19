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

**Treesitter**: Syntax highlighting, text objects and motions for functions, classes, arguments, conditionals and loops, and Neovim's built-in incremental selection by syntax node. nvim-treesitter-context pins the enclosing function/loop to the top of the window.

**Build**: Builds the project in the background and loads compiler errors into quickfix. The build system is detected from the current file upward (stopping at the git root):
- `Cargo.toml` runs `cargo build` from the outermost `Cargo.toml` (the workspace root).
- `CMakeLists.txt` configures a Debug build (so the debugger works) into `build/` from the outermost `CMakeLists.txt`, exporting `compile_commands.json` for clangd.
- `Makefile` runs `make` from the nearest `Makefile`.
- When several appear in one directory, Cargo beats CMake beats Make.

You can pick another detected command or type your own; the choice is remembered per project in `stdpath("data")/build-commands.json`.

**Debugging**: nvim-dap with `lldb-dap` for C, C++, and Rust, and nvim-dap-view as the UI (opens and closes with the session). Starting a session prompts for the executable, defaulting to `target/debug/` or `build/`. Rust sessions load rustc's LLDB formatters so `Vec`, `String`, etc. display readably.

**Formatting**: Format-on-save via conform.nvim. Each language has its own formatter configured. Lua style is set by `.stylua.toml`.

**Search**: Telescope for finding files, grepping, searching buffers/diagnostics/help/keymaps/TODOs/symbols. In the file finder and grep, two spaces start a glob filter: `config  *.lua` or `TODO  src/** !*.test.ts`. There's also a project-wide search-and-replace built on top of Telescope and quickfix.

**File Explorer**: Oil.nvim lets you edit your filesystem like a regular buffer.

**Git**: Gitsigns shows changed/added/deleted lines in the sign column and stages, resets, previews and blames hunks.

**Diagnostics**: Trouble.nvim gives you a list view of diagnostics, quickfix and symbols, and Neovim's native multiline diagnostics can be toggled under your code.

**Navigation**: Flash.nvim for label-based jumping and multi-line `f`/`t` motions, accelerated j/k so holding the key speeds up over time, and centered scrolling/search.

**Editing**: Built-in commenting, nvim-surround for manipulating pairs, vim-visual-multi for multi-cursor editing, autopairs, and Neovim's bundled undo tree.

**Terminals**: Toggleable splits that keep their session when hidden: a bottom shell, a right shell, and a Python REPL.

**Theme**: Vague with transparent background.

## Keymap Grammar

Leader is **Space**. Keymaps are built like sentences so they can be worked out instead of memorised.

**`<leader>` + domain + action.** The first key after leader names *what* you are working on, the second
says *what to do* with it, usually by its first letter: "**g**it **s**tage", "**c**ode **r**ename",
"**D**ebug **n**ext", "**o**ption **i**nlay hints".

| Domain | Meaning |
|---|---|
| `s` | Search: find things with Telescope |
| `c` | Code: LSP actions, formatting, navigation to implementations |
| `g` | Git: hunks, blame, log |
| `x` | Problems: diagnostic and quickfix lists |
| `o` | Option toggles: switch a display option on or off |
| `r` | Replace and rename |
| `w` | Window |
| `b` | Buffer |
| `t` | Terminal |
| `m` | Build (think "make") |
| `D` | Debug |
| `v` | Multi-cursor |
| `q` | Quickfix window |
| `L` | Lua: run code in Neovim |

**Shift means bigger or stronger.** Lowercase acts on the current thing, uppercase on more of it or a
heavier version: symbols in this file vs the project, a breakpoint vs a conditional breakpoint,
moving to a window vs moving the window.

**Brackets are motions.** `]` goes forward and `[` back, followed by the object's letter:
function, argument, class, hunk, quickfix entry, diagnostic, context.

**Frequent actions get single keys** after leader (file explorer, undo tree, clipboard), and the
LSP go-to motions stay on `g` like Vim's own.

Every mapping's description starts with its domain word, so `<leader>sk` then typing a domain
(`Git`, `Debug`, ...) lists all of its keys.

## Notes

- Format-on-save can be disabled globally (`vim.g.autoformat = false`) or per-buffer (`vim.b.autoformat = false`).
- Supports local project config via `.nvim.lua` / `.exrc` files.
- Run `:LspInfo` (or `:checkhealth vim.lsp`) to see configured servers and attached clients.
- Run `:Update` to update all plugins, then commit the updated `nvim-pack-lock.json`.
