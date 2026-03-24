-- Flutter run/debug via .vscode/launch.json
-- <leader>rr = run, <leader>rd = debug, <leader>rs = stop

local function find_flutter()
  local fvm = vim.fn.getcwd() .. "/.fvm/flutter_sdk/bin/flutter"
  if vim.uv.fs_stat(fvm) then return fvm end
  local system_flutter = vim.fn.trim(vim.fn.system("which flutter"))
  if vim.v.shell_error == 0 and system_flutter ~= "" then return system_flutter end
  return "flutter"
end

local function parse_launch_json()
  local path = vim.fn.getcwd() .. "/.vscode/launch.json"
  if not vim.uv.fs_stat(path) then return nil end
  local content = table.concat(vim.fn.readfile(path), "\n")
  -- Strip single-line comments (// ...)
  content = content:gsub("//.-\n", "\n")
  local ok, launch = pcall(vim.fn.json_decode, content)
  if not ok or not launch.configurations then return nil end
  local configs = {}
  for _, cfg in ipairs(launch.configurations) do
    if cfg.request == "launch" then
      table.insert(configs, cfg)
    end
  end
  return configs
end

local function build_cmd(cfg)
  local flutter = find_flutter()
  local cwd = vim.fn.getcwd()
  if cfg.cwd then cwd = cwd .. "/" .. cfg.cwd end

  local parts = { flutter, "run" }
  if cfg.program then
    table.insert(parts, "-t")
    table.insert(parts, cfg.program)
  end
  if cfg.args then
    for _, arg in ipairs(cfg.args) do
      table.insert(parts, arg)
    end
  end
  return table.concat(parts, " "), cwd
end

local function pick_and_run(debug_mode)
  local configs = parse_launch_json()
  if not configs or #configs == 0 then
    vim.notify("No launch configs in .vscode/launch.json", vim.log.levels.WARN)
    return
  end

  vim.ui.select(configs, {
    prompt = debug_mode and "Debug config:" or "Run config:",
    format_item = function(cfg) return cfg.name end,
  }, function(cfg)
    if not cfg then return end

    if debug_mode then
      local cwd = vim.fn.getcwd()
      if cfg.cwd then cwd = cwd .. "/" .. cfg.cwd end
      require("dap").run({
        type = "dart",
        request = "launch",
        name = cfg.name,
        program = cfg.program or "lib/main.dart",
        cwd = cwd,
        args = cfg.args or {},
      })
    else
      local cmd, cwd = build_cmd(cfg)
      vim.cmd("botright 10split | terminal cd " .. vim.fn.shellescape(cwd) .. " && " .. cmd)
      vim.cmd("setlocal nonumber norelativenumber signcolumn=no")
      vim.cmd("stopinsert")
      vim.cmd("wincmd k")
    end
  end)
end

return {
  -- DAP for Flutter debugging
  {
    "mfussenegger/nvim-dap",
    dependencies = {
      "nvim-neotest/nvim-nio",
      "rcarriga/nvim-dap-ui",
    },
    keys = {
      { "<leader>rr", function() pick_and_run(false) end, desc = "Run Flutter" },
      { "<leader>rd", function() pick_and_run(true) end, desc = "Debug Flutter" },
      { "<leader>rs", function()
        pcall(function() require("dap").terminate() end)
        for _, win in ipairs(vim.api.nvim_list_wins()) do
          local buf = vim.api.nvim_win_get_buf(win)
          if vim.bo[buf].buftype == "terminal" then
            pcall(vim.fn.jobstop, vim.bo[buf].channel)
            vim.api.nvim_win_close(win, true)
          end
        end
      end, desc = "Stop Flutter" },
      { "<leader>db", function() require("dap").toggle_breakpoint() end, desc = "Toggle Breakpoint" },
      { "<leader>dc", function() require("dap").continue() end, desc = "Continue" },
      { "<leader>dn", function() require("dap").step_over() end, desc = "Step Over" },
      { "<leader>di", function() require("dap").step_into() end, desc = "Step Into" },
      { "<leader>do", function() require("dap").step_out() end, desc = "Step Out" },
      { "<leader>dq", function() require("dap").terminate() end, desc = "Stop Debug" },
      { "<leader>du", function() require("dapui").toggle() end, desc = "Toggle Debug UI" },
      { "<leader>dr", function()
        local session = require("dap").session()
        if session then
          session:request("hotReload")
          vim.notify("Hot reloaded", vim.log.levels.INFO)
        end
      end, desc = "Hot Reload" },
      { "<leader>dR", function()
        local session = require("dap").session()
        if session then
          session:request("hotRestart")
          vim.notify("Hot restarted", vim.log.levels.INFO)
        end
      end, desc = "Hot Restart" },
    },
    config = function()
      local dap = require("dap")
      local dapui = require("dapui")
      dapui.setup()

      dap.listeners.after.event_initialized["dapui"] = function() dapui.open() end
      dap.listeners.before.event_terminated["dapui"] = function() dapui.close() end
      dap.listeners.before.event_exited["dapui"] = function() dapui.close() end

      -- Flutter debug adapter
      dap.adapters.dart = {
        type = "executable",
        command = find_flutter(),
        args = { "debug_adapter" },
      }
    end,
  },
}
