return {
  -- OpenCode: agentic AI assistant
  {
    "nickjvandyke/opencode.nvim",
    version = "*",
    dependencies = {
      {
        "folke/snacks.nvim",
        optional = true,
        opts = {
          input = {},
          picker = {
            actions = {
              opencode_send = function(...)
                return require("opencode").snacks_picker_send(...)
              end,
            },
            win = {
              input = {
                keys = {
                  ["<a-a>"] = { "opencode_send", mode = { "n", "i" } },
                },
              },
            },
          },
        },
      },
    },
    cmd = "Opencode",
    keys = {
      {
        "<leader>aa",
        function()
          require("opencode").ask("@this: ")
        end,
        desc = "OpenCode Ask @this",
        mode = { "n", "x" },
      },
      {
        "<leader>ab",
        function()
          require("opencode").ask("@buffer: ")
        end,
        desc = "OpenCode Ask @buffer",
        mode = { "n", "x" },
      },
      {
        "<leader>as",
        function()
          require("opencode").select()
        end,
        desc = "OpenCode Select (prompts/commands/sessions)",
      },
    },
    config = function()
      vim.g.opencode_opts = {
        events = { reload = true },
      }
      vim.o.autoread = true
    end,
  },
}
