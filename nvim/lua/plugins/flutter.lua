-- Flutter/Dart development: flutter-tools.nvim (LSP + device management),
-- nvim-dap debugging, treesitter, and LazyVim inlay-hint tweaks.

return {
  -- Dart syntax highlighting via treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "dart" },
    },
  },

  {
    "nvim-flutter/flutter-tools.nvim",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim",
    },
    opts = {
      fvm = true,
      decorations = {
        statusline = {
          -- Exposes the active run configuration (selected on :FlutterRun) via
          -- vim.g.flutter_tools_decorations.project_config, which lualine renders
          -- in the bottom bar (Android-Studio-style run-config indicator).
          project_config = true,
          device = true,
        },
      },
      debugger = {
        -- Disabled so :FlutterRun / <leader>rr does a plain `flutter run`
        -- (normal mode). :FlutterDebug / <leader>rd force-runs under DAP
        -- (force_debug=true overrides this flag), so debugging still works.
        enabled = false,
        exception_breakpoints = {},
        evaluate_to_string_in_debug_views = true,
      },
      closing_tags = { enabled = true },
      text_objects = { enabled = true },
      dev_log = {
        enabled = true,
        notify_errors = false,
        open_cmd = "15split",
        focus_on_open = true,
      },
      outline = { open_cmd = "30vnew", auto_open = false },
      lsp = {
        -- Let the Dart Analysis Server watch the filesystem itself instead of
        -- delegating to Neovim's client-side watcher. flutter-tools advertises
        -- didChangeWatchedFiles.dynamicRegistration = true by default, which makes
        -- dartls stop its own watching and rely on Neovim to report on-disk
        -- changes. On a large monorepo that watcher misses external edits
        -- (git, formatters, AI tools), so dartls never re-analyses closed files
        -- and their diagnostics go stale. Disabling it forces dartls back to its
        -- robust native watcher.
        capabilities = {
          workspace = {
            didChangeWatchedFiles = { dynamicRegistration = false },
          },
        },
        settings = {
          showTodos = true,
          completeFunctionCalls = true,
          enableSnippets = true,
          renameFilesWithClasses = "prompt",
          updateImportsOnRename = true,
        },
      },
    },
    config = function(_, opts)
      require("flutter-tools").setup(opts)

      -- Auto-detect run configurations from the workspace's .vscode/launch.json
      -- (like Android Studio / VS Code) and register them as flutter-tools
      -- project configs, so :FlutterRun prompts you to pick one and the choice
      -- shows in the statusline. Must run after setup() and before entering a
      -- dart buffer (setup_project only applies once).
      local configs = require("runconfig.launch_json").parse()
      if #configs > 0 then
        require("flutter-tools").setup_project(configs)
      end
    end,
  },

  -- Keep LazyVim from re-enabling LSP inlay hints on Dart buffers. Without this,
  -- LazyVim's LspAttach hook turns inlay hints back on (overriding flutter-tools'
  -- on_attach), showing dartls parameter-name hints in the dim "shadow" color.
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.inlay_hints = opts.inlay_hints or {}
      opts.inlay_hints.exclude = opts.inlay_hints.exclude or {}
      table.insert(opts.inlay_hints.exclude, "dart")
    end,
  },

  -- DAP UI for debugging (used by flutter-tools debugger)
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
    },
    keys = {
      -- Flutter run / debug / stop
      { "<leader>rr", ":FlutterRun<CR>", desc = "Run Flutter" },
      { "<leader>rd", ":FlutterDebug<CR>", desc = "Debug Flutter" },
      { "<leader>rs", ":FlutterQuit<CR>", desc = "Stop Flutter" },

      -- Device / emulator selection
      { "<leader>rf", ":FlutterDevices<CR>", desc = "Flutter Devices" },

      -- Hot reload / restart
      { "<leader>dr", ":FlutterReload<CR>", desc = "Hot Reload" },
      { "<leader>dR", ":FlutterRestart<CR>", desc = "Hot Restart" },

      -- DAP controls
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>dn", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dq", function() require("dap").terminate() end, desc = "Stop Debug" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle Debug UI" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()

      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

      -- Focus the stopped location when hitting a breakpoint
      dap.listeners.after.event_stopped["focus"] = function()
        vim.schedule(function()
          local session = dap.session()
          if not session then return end
          for _, win in ipairs(vim.api.nvim_list_wins()) do
            local buf = vim.api.nvim_win_get_buf(win)
            if vim.bo[buf].buftype == "" then
              vim.api.nvim_set_current_win(win)
              break
            end
          end
        end)
      end
    end,
  },
}
