return {
  -- GitHub Copilot
  {
    "zbirenbaum/copilot.lua",
    cmd = "Copilot",
    event = "InsertEnter",
    config = function()
      require("copilot").setup({
        suggestion = {
          enabled = true,
          auto_trigger = true,
          keymap = {
            accept = "<M-l>",
            accept_word = "<M-k>",
            next = "<M-]>",
            prev = "<M-[>",
            dismiss = "<M-e>",
          },
        },
        panel = { enabled = false },
      })
    end,
  },
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
              opencode_send = function(...) return require("opencode").snacks_picker_send(...) end,
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
        "<leader>ao",
        function() require("opencode").ask("@this: ") end,
        desc = "OpenCode Ask (selection/buffer)",
        mode = { "n", "x" },
      },
      {
        "<leader>as",
        function() require("opencode").select() end,
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
