return {
  "mfussenegger/nvim-dap",
  dependencies = {
    -- Creates a beautiful UI for DAP
    {
      "rcarriga/nvim-dap-ui",
      dependencies = { "nvim-neo-tree/nvim-nio" }, -- Required dependency for dap-ui
      config = function()
        local dapui = require("dapui")
        dapui.setup({
          -- Configure the layout of the DAP UI
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
      end,
    },

    -- Automatically installs and configures DAP adapters
    {
      "jay-babu/mason-nvim-dap.nvim",
      config = function()
        require("mason-nvim-dap").setup({
          -- A list of adapters to ensure are installed
          ensure_installed = {
            "codelldb", -- For Rust
            "cpptools", -- For C/C++
          },
          -- This handles the automatic setup of adapters
          handlers = {},
        })
      end,
    },
  },
  config = function()
    local dap = require("dap")
    local dapui = require("dapui")

    -- Dap UI listeners to automatically open and close the UI
    dap.listeners.after.event_initialized["dapui_config"] = function()
      dapui.open()
    end
    dap.listeners.before.event_terminated["dapui_config"] = function()
      dapui.close()
    end
    dap.listeners.before.event_exited["dapui_config"] = function()
      dapui.close()
    end

    -- Persistent variables to cache the last used program and args for each language
    local c_last_program = ""
    local c_last_args_str = ""
    local rust_last_program = vim.fn.getcwd() .. "/target/debug/"
    local rust_last_args_str = ""

    --- C/C++ Configuration ---
    dap.configurations.c = {
      {
        name = "Launch C/C++ (GDB)",
        type = "cppdbg", -- The adapter type installed by mason-nvim-dap
        request = "launch",
        program = function()
          local program_path = vim.fn.input("Path to executable: ", c_last_program, "file")
          c_last_program = program_path
          return program_path
        end,
        args = function()
          local args_str = vim.fn.input("Arguments: ", c_last_args_str)
          c_last_args_str = args_str
          if args_str == "" then
            return {}
          end
          return vim.split(args_str, " ")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        console = "integratedTerminal",
        MIMode = "gdb", -- Use GDB on Arch Linux
        setupCommands = {
          {
            description = "Enable pretty-printing for gdb",
            text = "-enable-pretty-printing",
            ignoreFailures = true,
          },
        },
      },
    }
    -- Make cpp a copy of the c configuration
    dap.configurations.cpp = dap.configurations.c

    --- Rust Configuration ---
    dap.configurations.rust = {
      {
        name = "Launch Rust (CodeLLDB)",
        type = "codelldb", -- The adapter type installed by mason-nvim-dap
        request = "launch",
        program = function()
          local program_path = vim.fn.input("Path to executable: ", rust_last_program, "file")
          rust_last_program = program_path
          return program_path
        end,
        args = function()
          local args_str = vim.fn.input("Arguments: ", rust_last_args_str)
          rust_last_args_str = args_str
          if args_str == "" then
            return {}
          end
          return vim.split(args_str, " ")
        end,
        cwd = "${workspaceFolder}",
        stopOnEntry = false,
        console = "integratedTerminal",
        -- A great feature for Rust, stops the debugger on panics
        breakOnRustPanic = true,
      },
    }
  end,
}
