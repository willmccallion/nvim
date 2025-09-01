vim.pack.add({
  'https://github.com/mfussenegger/nvim-dap',
  'https://github.com/rcarriga/nvim-dap-ui',
  'https://github.com/nvim-neotest/nvim-nio',
  'https://github.com/williamboman/mason.nvim',
  'https://github.com/jay-babu/mason-nvim-dap.nvim'
})

require('mason').setup()
require('mason-nvim-dap').setup({
  ensure_installed = {
    "codelldb",
    "cppdbg",
  },
  handlers = {},
})

local dapui = require("dapui")
dapui.setup({
  layouts = {
    {
      elements = {
        { id = "scopes", size = 0.35 },
        { id = "breakpoints", size = 0.15 },
        { id = "stacks", size = 0.25 },
        { id = "watches", size = 0.25 },
      },
      size = 40,
      position = "left",
    },
    {
      elements = {
        { id = "repl", size = 0.5 },
        { id = "console", size = 0.5 },
      },
      size = 10,
      position = "bottom",
    },
  },
})

local dap = require("dap")

dap.listeners.after.event_initialized["dapui_config"] = function()
  dapui.open()
end
dap.listeners.before.event_terminated["dapui_config"] = function()
  dapui.close()
end
dap.listeners.before.event_exited["dapui_config"] = function()
  dapui.close()
end

local c_last_program = ""
local c_last_args_str = ""
local rust_last_program = vim.fn.getcwd() .. "/target/debug/"
local rust_last_args_str = ""

dap.configurations.c = {
  {
    name = "Launch C/C++ (GDB)",
    type = "cppdbg",
    request = "launch",
    program = function()
      local program_path = vim.fn.input("Path to executable: ", c_last_program, "file")
      c_last_program = program_path
      return program_path
    end,
    args = function()
      local args_str = vim.fn.input("Arguments: ", c_last_args_str)
      c_last_args_str = args_str
      return vim.split(args_str, " ")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    MIMode = "gdb",
  },
}
dap.configurations.cpp = dap.configurations.c

dap.configurations.rust = {
  {
    name = "Launch Rust (CodeLLDB)",
    type = "codelldb",
    request = "launch",
    program = function()
      local program_path = vim.fn.input("Path to executable: ", rust_last_program, "file")
      rust_last_program = program_path
      return program_path
    end,
    args = function()
      local args_str = vim.fn.input("Arguments: ", rust_last_args_str)
      rust_last_args_str = args_str
      return vim.split(args_str, " ")
    end,
    cwd = "${workspaceFolder}",
    stopOnEntry = false,
    breakOnRustPanic = true,
  },
}

local map = vim.keymap.set
map("n", "<F9>", function() require("dap").toggle_breakpoint() end)
map("n", "<F5>", function() require("dap").continue() end)
map("n", "<F10>", function() require("dap").step_over() end)
map("n", "<F11>", function() require("dap").step_into() end)
map("n", "<F12>", function() require("dap").step_out() end)
map("n", "<leader>du", function() require("dapui").toggle() end)

