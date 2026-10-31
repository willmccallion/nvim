# Neovim Configuration

My Neovim config for C, C++, Rust, Python, Lua, Nix, SystemVerilog, and Zig.
Everything is in Lua and uses the built-in `vim.pack` plugin system. Plugin versions are pinned in `nvim-pack-lock.json`.

## Getting Started

Requires **Neovim 0.13+**, a **Nerd Font**, **ripgrep** (for grep/search), and a **C compiler** (for treesitter parsers).

For LSP support, install the language servers you need: `clangd`, `rust-analyzer`, `lua-language-server`, `pyright`, `ruff`, `nixd`, `slang-server`, `zls`.
Same for formatters: `clang-format`, `rustfmt`, `stylua`, `ruff`, `nixfmt`, `verible-verilog-format`, `zig`.
Debugging prefers `lldb-dap` (ships with LLDB, and is called `lldb-vscode` before LLVM 18), looked up on `PATH` and under `/usr/lib/llvm-*/bin`; set `vim.g.lldb_dap_command` to its path on a machine that keeps it elsewhere. Failing that it falls back to `gdb`, which has spoken DAP natively since version 14.
The config picks them up automatically if they're on your PATH.

## How It's Organized

```
init.lua             Loads config first, then plugins by category
lsp/                 One file per language server (clangd, rust_analyzer, lua_ls, pyright, ruff, nixd, slang_server, zls)
lua/
  config/            Options, keymaps, globals, autocommands, terminal toggles, input prompt
  plugins/
    ui/              Notifications, colorscheme, file explorer (oil), diagnostics, sticky context
    coding/          Completion, formatting, treesitter, autopairs, snippets
      build/         Build runner (detection, per-project storage, runner)
    debug/           Debugger (nvim-dap + nvim-dap-view)
    editor/          Navigation, search, git, surround, undo tree
      telescope/     Fuzzy finder (setup, glob filter, file/grep/keymap pickers)
    lsp/             LSP enablement and keymaps
```

To add a language server, drop a `lsp/<name>.lua` returning its config and add the name to `vim.lsp.enable` in `lua/plugins/lsp/init.lua`.
To add a treesitter language, add the parser name to the `parsers` list in `lua/plugins/coding/treesitter.lua`.

## What's In Here

**LSP**: Native `vim.lsp.config`/`vim.lsp.enable`, with server configs in the runtime `lsp/` directory. Completion is handled by nvim-cmp with LSP, snippet, path, and buffer sources. `<leader>cr` renames a symbol across the project, asking for the new name in the prompt float. `<leader>oc` shows code lenses and `<leader>cl` runs the one on the cursor's line; `<leader>oi` does the same for inlay hints. Both start off, so a buffer stays quiet until you ask. `<leader>cc` and `<leader>cC` list the callers of the symbol under the cursor and the functions it calls; `<leader>ch` and `<leader>cH` do the same for subtypes and supertypes, in the quickfix list since Telescope has no picker for them. In C and C++, `<leader>co` switches between a header and its source file, as clangd matches them. In a flake that defines `nixosConfigurations.<this host>`, nixd completes and documents that system's own options, home-manager and other module options included, evaluated from the flake and its locked nixpkgs.

**Treesitter**: Syntax highlighting, indentation (for languages whose parser has indent rules; the rest keep Vim's own), text objects and motions for functions, classes, arguments, conditionals and loops, and Neovim's built-in incremental selection by syntax node. nvim-treesitter-context pins the enclosing function/loop to the top of the window. Tags in comments (`TODO:`, `FIXME:`, `NOTE:`, `HACK:`) are coloured by the `comment` parser.

**Build**: Builds the project in the background and loads compiler errors into quickfix. The build system is detected from the current file upward (stopping at the git root):
- `Cargo.toml` runs `cargo build` from the outermost `Cargo.toml` (the workspace root).
- `CMakeLists.txt` configures a Debug build (so the debugger works) into `build/` from the outermost `CMakeLists.txt`, exporting `compile_commands.json` for clangd.
- `Makefile` runs `make` from the nearest `Makefile`.
- When several appear in one directory, Cargo beats CMake beats Make.

You can pick another detected command or type your own; the choice is remembered per project in `stdpath("data")/build-commands.json`.

`<leader>mr` runs the project's run command, asking for one the first time and reusing it afterwards; `<leader>mP` picks from the ones you have used or takes a new one. A run shares the build's output window and status, but its output is the program's own, so none of it is parsed into quickfix.

`<leader>mt` runs the test the cursor is in, in the build's output window, with compile errors and the line each failing test panicked on in quickfix. In Rust that is a `#[test]` function (or `#[tokio::test]` and the like), run by its full path with `--exact`, which is worked out from the file's place under `src/` or `tests/` and the `mod` blocks around it; outside a test but inside a `mod` block it runs every test in that module. A test path that matches nothing passes in cargo, so the status says when no test ran. In Python it is a pytest `test*` function or `Test*` class, run with `python3 -m pytest` from the directory with the project's pytest config.

**Debugging**: nvim-dap with `lldb-dap` for C, C++, and Rust, and nvim-dap-view as the UI, in a split on the right that opens and closes with the session. The first `<leader>dd` in a project prompts for the executable, defaulting to `target/debug/` or `build/`, and the program and arguments are remembered per project (beside the build commands), so later ones launch them straight away; `<leader>dD` asks again. In a file dap has no setup for, like a compiler's test inputs, it offers the C and C++ launches. If it does not exist or was built without debug info (where breakpoints would never be hit), it offers to build a debug build first, with `p build -d` where the shell's `p` is installed and otherwise `cargo build` or a CMake Debug build, and then debugs that; a plain Makefile only gets told to add `-g`. The view opens on Scopes, the frame's variables as a tree. While stopped, `<leader>dt` shows every variable in the frame with its type, struct fields and container elements included, and `<leader>dT` shows the definition of the type of the variable under the cursor (or of a type named there). While stopped, `<leader>dh` inspects the value under the cursor in a float you can expand into nested fields, `<leader>dv` fuzzy-searches the frame's variables (struct fields included) and pins the one you pick to the Watches panel, and `<leader>dV` toggles every variable's value inline in the code. A run that ends with a non-zero status reopens the view on the REPL, where the program's own output and its exit status are, rather than closing and leaving a failure looking like a clean run. `<leader>dp` sets a log point, which prints and carries on instead of stopping; `{}` interpolates an expression, so `i = {i}` reads like the printf you would otherwise have added and removed. Rust sessions load rustc's LLDB formatters so `Vec`, `String`, etc. display readably.

**Formatting**: Format-on-save via conform.nvim. Each language has its own formatter configured. Lua style is set by `.stylua.toml`.

**Search**: Telescope for finding files, grepping, searching buffers/diagnostics/help/keymaps/symbols. In the file finder and grep, two spaces start a glob filter: `config  *.lua` or `TODO  src/** !*.test.ts`. `<leader>st` lists every `TODO:`, `WIP:`, `HACK:`, `WARN:`, `WARNING:`, `FIX:`, `FIXME:` and `BUG:` in the project, and typing narrows the list. Search and replace is grug-far: `<leader>rw` for the current file and `<leader>rp` for the project, both prefilled from the word under the cursor or the visual selection. Matches are listed with the replacement rendered in place, and nothing is written until you sync it back.

**File Explorer**: Oil.nvim lets you edit your filesystem like a regular buffer.

**Git**: Gitsigns shows changed/added/deleted lines in the sign column and stages, resets, previews and blames hunks. `<leader>gd` lists every changed file in a panel on the left, grouped by folder. The file under the cursor previews on the right, opened at its first change since the last commit and folded down to the changes with three lines around each, each change shown as a before and after: the old lines in red above the new ones in green, with the part that differs marked in both (kept up to date as you edit); `]h`/`[h` step between changes, staged ones included, `zR` unfolds the rest and `zM` folds it again. `<CR>` moves into the file and keeps it open, where a file you only previewed closes once you move on. A deleted file shows read-only as it was before. The list updates on save and whenever you return to it, and `<leader>gd` closes it and takes you back to the file and spot you opened it from, with the folds and colours put back. `<leader>gD` does the same for everything changed since a commit you pick from the log (each one's author and diff shown; typing a name narrows the list to that person's commits, and `<C-o>` to only yours), all the way back to the first. A second picker then sets where the changes run up to: your files as they are now (the first entry: committed since, staged, unstaged and untracked, with the preview, folds, tint and `]h` all measured against that commit), or one of the later commits, whose files preview as read-only copies shown the same way, `]h` included. The second picker is skipped when nothing comes after the commit, and when nothing has changed since it at all, the panel shows what that commit itself changed. `:GitChanges [older [newer]]` opens it from the command line, skipping the pickers it is given, and `:GitChanges --commit [commit]` lists what one commit changed from the one before it, picked from the log when not given, and `:GitChanges --cached [commit]` lists what is staged, previewed as read-only copies, against that commit or `HEAD` (the dotfiles' `g diff` uses all three). `<leader>gh` lists only the commits that changed the function under the cursor, or the selected lines, by the same idea of a function as `]f`; each one previews its change to that code, `<C-o>` narrows the list to your commits, and picking one opens the panel on that commit at this file. Uncommitted edits are allowed for, so they never shift it onto other code. Removed lines show a hunk at a time with `<leader>gp`. `<leader>ob` toggles a faint blame (author, when, commit subject) at the end of the cursor's line.

**Status line**: Neovim's default, plus the language servers attached to the buffer, so one that never started is easy to spot.

**Diagnostics**: The message for the cursor's line shows under it, so the rest of the file stays quiet. `<leader>ol` widens that to every line and `<leader>cd` opens the full message in a float.

**Pinned files**: `<leader>a` pins the current file and `<leader>1` to `<leader>4` open pins 1 to 4, where the cursor last was in them. Each project (the git root) has its own pins, kept in `stdpath("data")/pins.json`. `<leader>A` shows them as a buffer, numbered by line: move lines to renumber them, `dd` to unpin, `<CR>` to open one; it saves when it closes.

`<leader>cy` copies the cursor's place as `path:line`, relative to the git root, or `path:first-last` for the lines of a visual selection, to paste into a chat, an issue or a note.

**Navigation**: Flash.nvim for label-based jumping and multi-line `f`/`t` motions, `j`/`k` that move by screen line unless given a count, and centered scrolling/search. `S` labels every syntax node enclosing the cursor at once and selects the one you pick, where Neovim's own `an` widens the selection a node per press; it stays out of visual mode, which is nvim-surround's `S`.

**Folding**: Folds follow the syntax tree, and a language server that reports folding ranges takes over per window when it attaches, since it knows about things the tree does not, like a run of imports. Files open with every fold up, so folding collapses what you choose rather than hiding a file on arrival. Vim's own `z` keys drive it: `za` toggles the fold under the cursor, `zR` opens all and `zM` closes all.

**Editing**: Built-in commenting, nvim-surround for manipulating pairs, autopairs, and Neovim's bundled undo tree.

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
| `o` | Option toggles: switch a display option on or off |
| `r` | Replace: search and replace across a file or the project |
| `w` | Window |
| `b` | Buffer |
| `t` | Terminal |
| `m` | Build (think "make") |
| `d` | Debug |
| `L` | Lua: run code in Neovim |

**Shift means bigger or stronger.** Lowercase acts on the current thing, uppercase on more of it or a
heavier version: symbols in this file vs the project, a breakpoint vs a conditional breakpoint,
moving to a window vs moving the window.

**Brackets are motions.** `]` goes forward and `[` back, followed by the object's letter: function,
argument, hunk and context here, plus the quickfix, location, diagnostic and buffer motions Neovim
itself provides. Classes sit on `]]` and `[[`, the pair nvim-treesitter-textobjects
uses, because `]c` and `[c` are Vim's diff-change motions. `]a` and `[a` take parameters rather than
Neovim's argument-list, which this config never uses. `;` repeats the last of these forward and `,` back,
whichever it was, except `[x`, which only goes up. A shifted letter moves the thing rather than moving
to it, as `<leader>wH` moves a window where `<leader>wh` moves to one: `]A` and `]F` swap the argument or
function with its neighbour, carrying the separators with it.

**Frequent actions get single keys** after leader (file explorer, undo tree, clipboard, quickfix, pins), and the
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
