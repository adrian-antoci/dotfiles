-- OpenCode TUI + editor context via opencode.nvim (LazyVim / snacks).
-- Docs: https://github.com/NickvanDyke/opencode.nvim

local side = require("config.side_panels")
local opencode_cmd = side.OPENCODE_CMD

local function snacks_terminal_opts()
  return side.opencode_opts()
end

return {
  {
    "folke/which-key.nvim",
    opts = {
      spec = {
        { "<leader>o", group = "opencode", icon = { icon = "󰚩 ", color = "purple" } },
      },
    },
  },

  {
    "NickvanDyke/opencode.nvim",
    version = "*",
    lazy = false,
    dependencies = {
      "folke/snacks.nvim",
    },
    keys = {
      {
        "<leader>oa",
        function()
          require("opencode").ask("@this: ")
        end,
        mode = { "n", "x" },
        desc = "Ask",
      },
      {
        "<leader>os",
        function()
          require("opencode").select()
        end,
        mode = { "n", "x" },
        desc = "Select prompt",
      },
      {
        "<leader>op",
        function()
          require("opencode").prompt("@this ")
        end,
        mode = { "n", "x" },
        desc = "Prompt with selection",
      },
      {
        "<leader>ot",
        function()
          require("snacks.terminal").toggle(opencode_cmd, snacks_terminal_opts())
        end,
        mode = { "n", "t" },
        desc = "Toggle TUI",
      },
      {
        "<leader>on",
        function()
          require("opencode").command("session.new")
        end,
        desc = "New session",
      },
      {
        "<leader>ou",
        function()
          require("opencode").command("session.half.page.up")
        end,
        desc = "Scroll up",
      },
      {
        "<leader>od",
        function()
          require("opencode").command("session.half.page.down")
        end,
        desc = "Scroll down",
      },
      {
        "<leader>oi",
        function()
          require("opencode").command("session.interrupt")
        end,
        desc = "Interrupt",
      },
      {
        "go",
        function()
          return require("opencode").operator("@this ")
        end,
        mode = { "n", "x" },
        desc = "Append range to OpenCode",
        expr = true,
      },
      {
        "goo",
        function()
          return require("opencode").operator("@this ") .. "_"
        end,
        desc = "Append line to OpenCode",
        expr = true,
      },
      {
        "<C-.>",
        function()
          require("snacks.terminal").toggle(opencode_cmd, snacks_terminal_opts())
        end,
        mode = { "n", "t" },
        desc = "Toggle OpenCode",
      },
    },
    config = function()
      ---@type opencode.Opts
      vim.g.opencode_opts = {
        server = {
          start = function()
            require("snacks.terminal").open(opencode_cmd, snacks_terminal_opts())
          end,
        },
      }

      -- Reveal TUI when a prompt is submitted
      vim.api.nvim_create_autocmd("User", {
        pattern = { "OpencodeEvent:tui.command.execute" },
        callback = function(args)
          ---@type opencode.server.Event
          local event = args.data.event
          if event.properties.command == "prompt.submit" then
            local win = require("snacks.terminal").get(opencode_cmd, { create = false })
            if win then
              win:show()
            end
          end
        end,
      })
    end,
  },

  -- snacks input/picker improve Ask and Select
  {
    "folke/snacks.nvim",
    opts = {
      input = { enabled = true },
      picker = { enabled = true },
    },
  },
}
