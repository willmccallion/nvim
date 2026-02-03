# Neovim Configuration

This is a configuration for Neovim focused on C, C++, Rust, and Lua development. It uses Lua for configuration and manages plugins via a package system.

## Requirements

### Neovim
Requires Neovim 0.12.0 or later since it uses the new vim.pack.

### External Dependencies
The following tools are required for full functionality:

*   **ripgrep**: Required for Telescope live grep.
*   **Nerd Font**: Required for UI icons.
*   **C Compiler**: Required for compiling Treesitter parsers.

### Language Servers
Install the following language servers for LSP support:

*   `clangd` (C/C++)
*   `rust-analyzer` (Rust)
*   `lua-language-server` (Lua)

### Formatters
Install the following tools for code formatting:

*   `clang-format` (C/C++)
*   `rustfmt` (Rust)
*   `stylua` (Lua)

## Structure

*   `lua/config/`: Core configuration (options, keymaps, autocommands).
*   `lua/plugins/`: Plugin configuration organized by category (`coding`, `editor`, `lsp`, `ui`).
*   `lua/plugins/lsp/servers/`: Language server specific configurations.

## Key Features

*   **LSP**: Native LSP client configured for C, C++, Rust, and Lua.
*   **Completion**: Autocompletion provided by nvim-cmp with snippet support.
*   **Formatting**: Auto-formatting on save using conform.nvim.
*   **Syntax Highlighting**: Treesitter enabled for syntax highlighting and indentation.
*   **Fuzzy Finding**: Telescope for finding files, buffers, and text.
*   **File Explorer**: Oil.nvim for editing the filesystem as a buffer.
*   **Git**: Gitsigns for hunk management and blame.
*   **Navigation**: Flash.nvim for quick jumping and accelerated-jk for vertical movement.
*   **Theme**: Terafox (Nightfox).

## Keybindings

The leader key is set to `Space`.

### General
*   `<leader>e`: Open file explorer (Oil).
*   `<leader>q`: Open diagnostic quickfix list.
*   `<leader>u`: Toggle UndoTree.
*   `<C-l>`: Toggle search highlighting.
*   `<leader>y` / `<Space>p`: Copy/Paste to system clipboard.
*   `<leader>xx`: Source current file.
*   `<leader>x`: Execute Lua line/selection.

### Navigation
*   `j` / `k`: Accelerated vertical navigation.
*   `s`: Flash jump to character.
*   `<leader>bb`: Switch to alternate buffer.
*   `<leader>bn` / `<Space>bp`: Next/Previous buffer.

### Telescope
*   `<leader>sf`: Find files.
*   `<leader>sg`: Live grep.
*   `<leader>sw`: Search current word.
*   `<leader>sk`: Search keymaps
*   `<leader>st`: Search TODOs.
*   `<leader>/`: Find open buffers.
*   `<leader><Space>`: Fuzzily search in current buffer.

### LSP
*   `gd`: Go to definition.
*   `gr`: Go to references.
*   `K`: Hover documentation.
*   `<leader>rn`: Rename symbol.
*   `<leader>ca`: Code action.
*   `<leader>f`: Format buffer.
*   `<leader>l`: Toggle LSP lines.

### Git
*   `<leader>hs`: Stage hunk.
*   `<leader>hr`: Reset hunk.
*   `<leader>hb`: Blame line.
*   `<leader>hu`: Undo stage hunk.
*   `<leader>hp`: Preview hunk.

### AI Assistant
*   `<leader>aa`: Start AI assistant (Graft).
*   `<leader>am`: Select AI model.
*   `<leader>as`: Stop AI job.

## Notes

*   **Graft**: The configuration references a local plugin `graft.nvim` in `~/projects/`. You may need to adjust `lua/plugins/graft.lua` to point to a valid location or remove it if not used.
