return {
  cmd = { 'rust-analyzer' },
  filetypes = { 'rust' },
  root_markers = { 'Cargo.toml', 'rust-project.json' },

  capabilities = capabilities,

  settings = {
    ['rust-analyzer'] = {
      inlayHints = {
         enable = true,
      },
      check = {
        command = "clippy"
      }
    }
  }
}
