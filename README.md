# Neovim Configuration

My Neovim config for C, C++, Rust, Python, Lua, and Nix.
Everything is in Lua and uses the built-in `vim.pack` plugin system. Plugin versions are pinned in `nvim-pack-lock.json`.

## Getting Started

Requires **Neovim 0.13+**, a **Nerd Font**, **ripgrep** (for grep/search), and a **C compiler** (for treesitter parsers).

For LSP support, install the language servers you need: `clangd`, `rust-analyzer`, `lua-language-server`, `pyright`, `nixd`.
Same for formatters: `clang-format`, `rustfmt`, `stylua`, `black`/`isort`, `nixfmt`.
Debugging prefers `lldb-dap` (ships with LLDB, and is called `lldb-vscode` before LLVM 18), looked up on `PATH` and under `/usr/lib/llvm-*/bin`; set `vim.g.lldb_dap_command` to its path on a machine that keeps it elsewhere. Failing that it falls back to `gdb`, which has spoken DAP natively since version 14.
The config picks them up automatically if they're on your PATH.

## How It's Organized

```
init.lua             Loads config first, then plugins by category
lsp/                 One file per language server (clangd, rust_analyzer, lua_ls, pyright, nixd)
lua/
  config/            Options, keymaps, globals, autocommands, terminal toggles, input prompt
  plugins/
    ui/              Notifications, colorscheme, file explorer (oil), diagnostics, sticky context
    coding/          Completion, formatting, treesitter, autopairs, snippets
      build/         Build runner (detection, per-project storage, runner)
    debug/           Debugger (nvim-dap + nvim-dap-view)
    editor/          Navigation, search, git, surround, multi-cursor, undo tree
      telescope/     Fuzzy finder (setup, glob filter, file/grep/keymap pickers)
    lsp/             LSP enablement and keymaps
```

To add a language server, drop a `lsp/<name>.lua` returning its config and add the name to `vim.lsp.enable` in `lua/plugins/lsp/init.lua`.
To add a treesitter language, add the parser name to the `parsers` list in `lua/plugins/coding/treesitter.lua`.

## What's In Here

**LSP**: Native `vim.lsp.config`/`vim.lsp.enable`, with server configs in the runtime `lsp/` directory. Completion is handled by nvim-cmp with LSP, snippet, path, and buffer sources. Renaming a symbol goes through inc-rename, so `'inccommand'` previews every affected site as you type. `<leader>oc` shows code lenses and `<leader>cl` runs the one on the cursor's line; `<leader>oi` does the same for inlay hints. Both start off, so a buffer stays quiet until you ask. `<leader>cc` and `<leader>cC` list the callers of the symbol under the cursor and the functions it calls; `<leader>ch` and `<leader>cH` do the same for subtypes and supertypes, in the quickfix list since Telescope has no picker for them.

**Treesitter**: Syntax highlighting, text objects and motions for functions, classes, arguments, conditionals and loops, and Neovim's built-in incremental selection by syntax node. nvim-treesitter-context pins the enclosing function/loop to the top of the window.

**Build**: Builds the project in the background and loads compiler errors into quickfix. The build system is detected from the current file upward (stopping at the git root):
- `Cargo.toml` runs `cargo build` from the outermost `Cargo.toml` (the workspace root).
- `CMakeLists.txt` configures a Debug build (so the debugger works) into `build/` from the outermost `CMakeLists.txt`, exporting `compile_commands.json` for clangd.
- `Makefile` runs `make` from the nearest `Makefile`.
- When several appear in one directory, Cargo beats CMake beats Make.

You can pick another detected command or type your own; the choice is remembered per project in `stdpath("data")/build-commands.json`.

`<leader>mr` runs the project's run command, asking for one the first time and reusing it afterwards; `<leader>mP` picks from the ones you have used or takes a new one. A run shares the build's output window and status, but its output is the program's own, so none of it is parsed into quickfix.

**Debugging**: nvim-dap with `lldb-dap` for C, C++, and Rust, and nvim-dap-view as the UI, in a split on the right that opens and closes with the session. Starting a session prompts for the executable, defaulting to `target/debug/` or `build/`. While stopped, `<leader>dh` inspects the value under the cursor in a float you can expand into nested fields, `<leader>dv` fuzzy-searches the frame's variables (struct fields included) and pins the one you pick to the Watches panel, and `<leader>dV` toggles every variable's value inline in the code. A run that ends with a non-zero status reopens the view on the REPL, where the program's own output and its exit status are, rather than closing and leaving a failure looking like a clean run. `<leader>dp` sets a log point, which prints and carries on instead of stopping; `{}` interpolates an expression, so `i = {i}` reads like the printf you would otherwise have added and removed. Rust sessions load rustc's LLDB formatters so `Vec`, `String`, etc. display readably.

**Formatting**: Format-on-save via conform.nvim. Each language has its own formatter configured. Lua style is set by `.stylua.toml`.

**Search**: Telescope for finding files, grepping, searching buffers/diagnostics/help/keymaps/TODOs/symbols. In the file finder and grep, two spaces start a glob filter: `config  *.lua` or `TODO  src/** !*.test.ts`. Search and replace is grug-far: `<leader>rw` for the current file and `<leader>rp` for the project, both prefilled from the word under the cursor or the visual selection. Matches are listed with the replacement rendered in place, and nothing is written until you sync it back.

**File Explorer**: Oil.nvim lets you edit your filesystem like a regular buffer.

**Git**: Gitsigns shows changed/added/deleted lines in the sign column and stages, resets, previews and blames hunks.

**Diagnostics**: The message for the cursor's line shows under it, so the rest of the file stays quiet. `<leader>ol` widens that to every line and `<leader>cd` opens the full message in a float. Trouble.nvim gives you a list view of diagnostics, quickfix and symbols.

**Navigation**: Flash.nvim for label-based jumping and multi-line `f`/`t` motions, accelerated j/k so holding the key speeds up over time, and centered scrolling/search.

**Folding**: Folds follow the syntax tree, and a language server that reports folding ranges takes over per window when it attaches, since it knows about things the tree does not, like a run of imports. Files open with every fold up, so folding collapses what you choose rather than hiding a file on arrival. Vim's own `z` keys drive it: `za` toggles the fold under the cursor, `zR` opens all and `zM` closes all.

**Editing**: Built-in commenting, nvim-surround for manipulating pairs, vim-visual-multi for multi-cursor editing, autopairs, and Neovim's bundled undo tree.

**Terminals**: Toggleable splits that keep their session when hidden: a bottom shell, a right shell, and a Python REPL.

**Prompts and messages**: `vim.ui.input` opens a small float at the cursor instead of asking on the command line, so the code you are working on stays in view. `<CR>` confirms, `<Esc>` cancels, and `<Tab>` completes when the prompt takes a path. Messages go to fidget in the bottom right rather than the command line, where a long one would stop for a "Press ENTER" prompt; `:Fidget history` brings back ones that have faded.

**Theme**: Vague with transparent background.

## Keymap Grammar

Leader is **Space**. Keymaps are built like sentences so they can be worked out instead of memorised.

**`<leader>` + domain + action.** The first key after leader names *what* you are working on, the second
says *what to do* with it, usually by its first letter: "**g**it **s**tage", "**c**ode **r**ename",
"**d**ebug **n**ext", "**o**ption **i**nlay hints".

| Domain | Meaning |
|---|---|
| `s` | Search: find things with Telescope |
| `c` | Code: LSP actions, formatting, renaming, navigation to implementations |
| `g` | Git: hunks, blame, log |
| `x` | Problems: diagnostic and quickfix lists |
| `o` | Option toggles: switch a display option on or off |
| `r` | Replace: search and replace across a file or the project |
| `w` | Window |
| `b` | Buffer |
| `t` | Terminal |
| `m` | Build (think "make") |
| `d` | Debug |
| `v` | Multi-cursor |
| `L` | Lua: run code in Neovim |

**Shift means bigger or stronger.** Lowercase acts on the current thing, uppercase on more of it or a
heavier version: symbols in this file vs the project, a breakpoint vs a conditional breakpoint,
moving to a window vs moving the window.

**Brackets are motions.** `]` goes forward and `[` back, followed by the object's letter: function,
argument, hunk and context here, plus the quickfix, location, diagnostic and buffer motions Neovim
itself provides. Classes sit on `]]` and `[[`, the pair nvim-treesitter-textobjects
uses, because `]c` and `[c` are Vim's diff-change motions. `]a` and `[a` take parameters rather than
Neovim's argument-list, which this config never uses. A shifted letter moves the thing rather than moving
to it, as `<leader>wH` moves a window where `<leader>wh` moves to one: `]A` and `]F` swap the argument or
function with its neighbour, carrying the separators with it.

**Frequent actions get single keys** after leader (file explorer, undo tree, clipboard, quickfix), and the
LSP go-to motions stay on `g` like Vim's own.

**Local leader is `,`**, kept distinct from leader so a plugin that maps `<localleader>` keys inside its
own buffer cannot shadow a leader domain. grug-far's buffer keys are the ones that use it.

`<leader>sk` reads the grammar back to you. Every mapping is filed under the domain its key sequence
belongs to — the table above for leader keys, plus `Motion` for `[`/`]`, `Textobject` for `a`/`i` pairs,
`LSP` for the `g` go-tos and `Surround` for `ys`/`cs`/`ds` — and the list is ordered by domain, so an
empty prompt is already grouped and typing a domain (`git`, `debug`, ...) narrows to its keys. A mapping
that exists in several modes is one row, marked `nxo`, and `@` marks one that only the current buffer has.
Descriptions still lead with their domain word, so a search matches whether you think in keys or in words.
`<leader>sK` adds every unlabelled mapping Neovim and the plugins install, for when something is bound and
you cannot tell what to.

## Notes

- Format-on-save can be disabled globally (`vim.g.autoformat = false`) or per-buffer (`vim.b.autoformat = false`).
- Supports local project config via `.nvim.lua` / `.exrc` files.
- Run `:LspInfo` (or `:checkhealth vim.lsp`) to see configured servers and attached clients.
- Run `:Update` to update all plugins, then commit the updated `nvim-pack-lock.json`. It forwards to `:packupdate`, so it also takes plugin names, `++offline` and `++lockfile`, and completes all three.
