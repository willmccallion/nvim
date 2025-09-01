return {
  cmd = { 'clangd' },

  filetypes = { 'c', 'cpp', 'objc', 'objcpp', 'cuda' },
  root_markers = { '.git', 'compile_commands.json', 'compile_flags.txt' },
  capabilities = capabilities,

  settings = {}
}
