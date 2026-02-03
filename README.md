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
*   `lua/lsp/`: Language server specific configurations.
*   `lua/plugins/`: Plugin installation and configuration.

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
*   `<Space>e`: Open file explorer (Oil).
*   `<Space>q`: Open diagnostic quickfix list.
*   `<Space>u`: Toggle UndoTree.
*   `<C-l>`: Toggle search highlighting.
*   `<Space>y` / `<Space>p`: Copy/Paste to system clipboard.

### Navigation
*   `j` / `k`: Accelerated vertical navigation.
*   `s`: Flash jump to character.
*   `<Space>bb`: Switch to alternate buffer.
*   `<Space>bn` / `<Space>bp`: Next/Previous buffer.

### Telescope
*   `<Space>sf`: Find files.
*   `<Space>sg`: Live grep.
*   `<Space>sw`: Search current word.
*   `<Space>/`: Search in current buffer.

### LSP
*   `gd`: Go to definition.
*   `gr`: Go to references.
*   `K`: Hover documentation.
*   `<Space>rn`: Rename symbol.
*   `<Space>ca`: Code action.
*   `<Space>f`: Format buffer.

### Git
*   `<Space>hs`: Stage hunk.
*   `<Space>hr`: Reset hunk.
*   `<Space>hb`: Blame line.

### AI Assistant
*   `<Space>aa`: Start AI assistant (Graft).
*   `<Space>am`: Select AI model.
*   `<Space>as`: Stop AI job.

## Notes

*   **Graft**: The configuration references a local plugin `graft.nvim` in `~/projects/`. You may need to adjust `lua/plugins/graft.lua` to point to a valid location or remove it if not used.
