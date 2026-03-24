return {
  -- Augment Code: AI completions and chat
  {
    "augmentcode/augment.vim",
    lazy = false,
    keys = {
      { "<leader>ac", ":Augment chat<CR>", mode = { "n", "v" }, desc = "Augment Chat" },
      { "<leader>an", ":Augment chat-new<CR>", desc = "Augment New Chat" },
      { "<leader>at", ":Augment chat-toggle<CR>", desc = "Augment Toggle Chat" },
    },
  },
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
}
