-- ~/.config/nvim/lua/plugins/dap.lua

return {
  'mfussenegger/nvim-dap',
  dependencies = {
    {
      'rcarriga/nvim-dap-ui',
      dependencies = { 'nvim-neotest/nvim-nio' },
      config = function()
        require('dapui').setup({
          layouts = {
            {
              elements = { { id = 'scopes', size = 0.4 }, { id = 'breakpoints', size = 0.2 }, { id = 'stacks', size = 0.2 }, { id = 'watches', size = 0.2 } },
              size = 40,
              position = 'left',
            },
            { elements = { { id = 'repl', size = 0.5 }, { id = 'console', size = 0.5 } }, size = 10, position = 'bottom' },
          },
        })
      end,
    },
    {
      'jay-babu/mason-nvim-dap.nvim',
      config = function()
        require('mason-nvim-dap').setup({
          ensure_installed = { 'codelldb' }, -- Ensure your debugger is listed here
          handlers = {},
        })
      end,
    },
  },
  config = function()
    local dap, dapui = require('dap'), require('dapui')

    -- Automatically open and close the DAP UI when a session starts/ends
    dap.listeners.after.event_initialized['dapui_config'] = function() dapui.open() end
    dap.listeners.before.event_terminated['dapui_config'] = function() dapui.close() end
    dap.listeners.before.event_exited['dapui_config'] = function() dapui.close() end

    -- Persistent variables to cache the last used program and args for each language
    local cpp_last_program = vim.fn.getcwd() .. '/'
    local cpp_last_args_str = ''

    local rust_last_program = ''
    local rust_last_args_str = ''

    --- C/C++ Configuration ---
    dap.configurations.cpp = {
      {
        name = 'Launch C/C++ File',
        type = 'codelldb',
        request = 'launch',
        program = function()
          local program_path = vim.fn.input('Path to executable: ', cpp_last_program, 'file')
          cpp_last_program = program_path
          return program_path
        end,
        args = function()
          local args_str = vim.fn.input('Arguments: ', cpp_last_args_str)
          cpp_last_args_str = args_str
          return vim.split(args_str, ' ')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
      },
    }
    dap.configurations.c = dap.configurations.cpp

    --- Rust Configuration ---
    dap.configurations.rust = {
      {
        name = 'Launch Rust File',
        type = 'codelldb',
        request = 'launch',
        program = function()
          if rust_last_program == '' then
            -- Use the modern vim.fs.find to locate Cargo.toml by searching upwards
            local cargo_toml_path = vim.fs.find('Cargo.toml', { upward = true, path = vim.fn.getcwd() })

            if #cargo_toml_path > 0 then
              -- Get the directory containing Cargo.toml
              local project_root = vim.fn.fnamemodify(cargo_toml_path[1], ':h')
              -- Set the smart default path
              rust_last_program = project_root .. '/target/debug/'
            else
              -- Fallback if not in a Cargo project
              rust_last_program = vim.fn.getcwd() .. '/'
            end
          end

          local program_path = vim.fn.input('Path to executable: ', rust_last_program, 'file')
          rust_last_program = program_path
          return program_path
        end,
        args = function()
          local args_str = vim.fn.input('Arguments: ', rust_last_args_str)
          rust_last_args_str = args_str
          return vim.split(args_str, ' ')
        end,
        cwd = '${workspaceFolder}',
        stopOnEntry = false,
      },
    }
  end,
  keys = {
    { '<F5>', function() require('dap').continue() end, desc = 'DAP: Continue / Start' },
    { '<F9>', function() require('dap').toggle_breakpoint() end, desc = 'DAP: Toggle Breakpoint' },
    { '<F10>', function() require('dap').step_over() end, desc = 'DAP: Step Over' },
    { '<F11>', function() require('dap').step_into() end, desc = 'DAP: Step Into' },
    { '<F12>', function() require('dap').step_out() end, desc = 'DAP: Step Out' },
    { '<leader>du', function() require('dapui').toggle() end, desc = 'DAP: Toggle UI' },
  },
}
