--- slang-server LSP config for SystemVerilog and Verilog.
--- Built on the slang compiler, so diagnostics cover elaboration and types, not
--- just syntax. Per-project settings (flags, .f filelists) live in .slang/server.json.
--- Formatting is handled by conform (verible-verilog-format), not the server.

---@type vim.lsp.Config
return {
	cmd = { "slang-server" },
	filetypes = { "systemverilog", "verilog" },
	root_markers = { ".slang", ".git" },
}
