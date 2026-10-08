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
    -- Temporarily on PR #558 (nil check in update_device_from_output, issue
    -- #557). Revert to upstream once merged.
    url = "https://github.com/mmcdanielq/flutter-tools.nvim.git",
    branch = "fix/commands-update-device-from-output-nil-check",
    commit = "110d8023aff5d903d5413b7bc2e22556cd7b922a",
    lazy = false,
    dependencies = {
      "nvim-lua/plenary.nvim",
      "stevearc/dressing.nvim",
      -- Colorize ANSI escape codes that Flutter emits in the dev log, so the
      -- console shows real colors instead of raw sequences like ^[[38;5;3m.
      "m00qek/baleia.nvim",
    },
    config = function()
      require("flutter-tools").setup({
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
        closing_tags = {
          enabled = true,
        },
        text_objects = {
          enabled = true,
        },
        dev_log = {
          enabled = true,
          notify_errors = false,
          -- Open full-width at the very bottom; edgy.nvim (below) then docks this
          -- into an Android-Studio-style bottom tool panel.
          open_cmd = "botright 15split",
          focus_on_open = true,
        },
        outline = {
          open_cmd = "30vnew",
          auto_open = false,
        },
        lsp = {
          -- Let the Dart Analysis Server watch the filesystem itself instead of
          -- delegating to Neovim's client-side watcher. flutter-tools advertises
          -- didChangeWatchedFiles.dynamicRegistration = true by default, which makes
          -- dartls stop its own watching and rely on Neovim to report on-disk
          -- changes. On a large Melos monorepo (only `fd` available, no watchman)
          -- that watcher misses external edits (git, melos format, Claude Code), so
          -- dartls never re-analyses closed files and their diagnostics go stale.
          -- Disabling it forces dartls back to its robust native watcher.
          capabilities = {
            workspace = {
              didChangeWatchedFiles = {
                dynamicRegistration = false,
              },
            },
          },
          settings = {
            showTodos = true,
            completeFunctionCalls = true,
            enableSnippets = true,
            renameFilesWithClasses = "prompt",
            updateImportsOnRename = true,
          },
          on_attach = function(_, bufnr)
            vim.lsp.inlay_hint.enable(false, { bufnr = bufnr })
          end,
        },
      })

      -- Auto-detect VS Code and Android Studio Flutter run configurations
      -- and register them as flutter-tools
      -- project configs, so :FlutterRun prompts you to pick one and the choice
      -- shows in the statusline. Must run after setup() and before entering a
      -- dart buffer (setup_project only applies once).
      local configs = require("runconfig.launch_json").parse()
      if #configs > 0 then
        require("flutter-tools").setup_project(configs)
      end

      -- Android-Studio-style run manager: persistent run-config + device
      -- selectors (top-right toolbar) feeding a single Run/Debug action. Keymaps
      -- live in the nvim-dap spec below.
      require("runconfig").setup()

      -- Auto-follow the dev log: keep any window showing __FLUTTER_DEV_LOG__
      -- pinned to the newest line as Flutter streams output. flutter-tools appends
      -- via nvim_buf_set_lines (no TextChanged), so we attach to the buffer and
      -- react to on_lines. Following pauses when you scroll up to read history and
      -- resumes once the cursor is back near the bottom (tail -f behaviour).
      vim.api.nvim_create_autocmd({ "FileType", "BufWinEnter" }, {
        group = vim.api.nvim_create_augroup("FlutterDevLogFollow", { clear = true }),
        callback = function(args)
          local buf = args.buf
          if not vim.api.nvim_buf_get_name(buf):match("__FLUTTER_DEV_LOG__$") then
            return
          end
          if vim.b[buf].flutter_dev_log_follow then
            return
          end
          vim.b[buf].flutter_dev_log_follow = true
          vim.api.nvim_buf_attach(buf, false, {
            on_lines = function(_, bufnr)
              if not vim.api.nvim_buf_is_valid(bufnr) then
                return true
              end
              vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(bufnr) then
                  return
                end
                local last = vim.api.nvim_buf_line_count(bufnr)
                local prev = vim.b[bufnr].flutter_dev_log_lastcount or 0
                for _, win in ipairs(vim.fn.win_findbuf(bufnr)) do
                  -- Only follow if the cursor was at/near the previous end,
                  -- i.e. the user hasn't scrolled up to read older output.
                  if vim.api.nvim_win_get_cursor(win)[1] >= prev - 1 then
                    vim.api.nvim_win_set_cursor(win, { last, 0 })
                  end
                end
                vim.b[bufnr].flutter_dev_log_lastcount = last
              end)
            end,
          })
        end,
      })
    end,
  },

  -- Dock the Flutter dev-log console as an Android-Studio-style bottom tool
  -- panel (a proper edgebar) instead of a plain editor split, so opening files
  -- never disturbs it and it can be collapsed/toggled (<leader>rl, or q / <c-q>
  -- inside the panel). Only the __FLUTTER_DEV_LOG__ buffer is captured.
  {
    "folke/edgy.nvim",
    event = "VeryLazy",
    init = function()
      -- Required for edgebars to collapse fully and to stop the main splits
      -- jumping when the panel opens.
      vim.opt.laststatus = 3
      vim.opt.splitkeep = "screen"
    end,
    opts = {
      animate = { enabled = false },
      bottom = {
        {
          ft = "log",
          title = "Flutter Dev Log",
          size = { height = 0.3 },
          filter = function(buf)
            return vim.api.nvim_buf_get_name(buf):match("__FLUTTER_DEV_LOG__$") ~= nil
          end,
        },
      },
    },
  },

  -- Keep LazyVim from re-enabling LSP inlay hints on Dart buffers. Without this,
  -- LazyVim's LspAttach hook turns inlay hints back on (overriding flutter-tools'
  -- on_attach), showing dartls parameter-name hints on nameless/closure params in
  -- the dim "shadow" (LspInlayHint) color.
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
      -- Run manager: pick a run config / device once (Android-Studio-style),
      -- then Run/Debug uses both. See lua/runconfig.
      { "<leader>rc", function() require("runconfig").select_config() end, desc = "Select Run Config" },
      { "<leader>rf", function() require("runconfig").select_device() end, desc = "Select Device" },
      { "<leader>rr", function() require("runconfig").run() end, desc = "Run Flutter" },
      { "<leader>rd", function() require("runconfig").debug() end, desc = "Debug Flutter" },
      { "<leader>rs", function() require("runconfig").stop() end, desc = "Stop Flutter" },
      { "<leader>rl", function() require("runconfig").toggle_dev_log() end, desc = "Toggle Flutter Log" },
      { "<leader>rm", function() require("runconfig").mirror_device() end, desc = "Mirror Device (Android/iOS)" },

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
