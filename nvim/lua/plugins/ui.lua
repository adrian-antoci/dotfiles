return {
  -- Disable the top buffer tabs (bufferline). Buffers are still there and can be
  -- switched with <S-h>/<S-l>; there's just no tab bar across the top.
  { "akinsho/bufferline.nvim", enabled = false },

  -- The active Flutter run config + device are shown in the always-visible,
  -- top-right toolbar (see lua/runconfig/toolbar.lua), so no lualine segment here.
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    "nvim-mini/mini.icons",
    opts = {
      extension = {
        dart = { glyph = "\u{e615}", hl = "MiniIconsBlue" },
      },
      filetype = {
        dart = { glyph = "\u{e615}", hl = "MiniIconsBlue" },
      },
    },
  },
  {
    "sphamba/smear-cursor.nvim",
    event = "VeryLazy",
    opts = {
      stiffness = 0.8,
      trailing_stiffness = 0.6,
      distance_stop_animating = 0.5,
      hide_target_hack = false,
    },
  },
}
