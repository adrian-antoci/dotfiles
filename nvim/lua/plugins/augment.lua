return {
  -- Augment: official chat + inline completions (augment.vim).
  -- Completions are on; accept a visible suggestion with <Tab> (see keys below).
  {
    "augmentcode/augment.vim",
    -- `init` runs before the plugin loads, which the following globals require.
    init = function()
      -- Extra workspace context for chat + completions.
      vim.g.augment_workspace_folders = { "~/development/obsidian-app" }
      -- We map <Tab> ourselves below, so disable augment.vim's default Tab map.
      vim.g.augment_disable_tab_mapping = true
    end,
    -- Load on buffer read so inline completions are available without first
    -- running :Augment, and on the command for chat.
    event = { "BufReadPre", "BufNewFile" },
    cmd = "Augment",
    keys = {
      {
        -- <Tab> accepts an Augment suggestion ONLY when one is visible
        -- (tracked by the buffer-local b:_augment_suggestion, which holds a
        -- `lines` key while ghost text is shown). Otherwise it returns a real
        -- <Tab> so blink.cmp's own Tab mapping fires (accept menu item / jump
        -- snippet / indent) exactly as before.
        "<Tab>",
        function()
          local s = vim.b._augment_suggestion
          if type(s) == "table" and s.lines ~= nil then
            return "<cmd>call augment#Accept()<cr>"
          end
          return "<Tab>"
        end,
        desc = "Augment Accept Suggestion / Tab",
        mode = "i",
        expr = true,
        replace_keycodes = true,
      },
      {
        "<leader>Ac",
        ":Augment chat<CR>",
        desc = "Augment Chat",
        mode = { "n", "v" },
      },
      {
        "<leader>An",
        "<cmd>Augment chat-new<CR>",
        desc = "Augment Chat New",
      },
      {
        "<leader>At",
        "<cmd>Augment chat-toggle<CR>",
        desc = "Augment Chat Toggle",
      },
      {
        "<leader>As",
        "<cmd>Augment signin<CR>",
        desc = "Augment Sign In",
      },
    },
  },
}
