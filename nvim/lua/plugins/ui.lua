return {
  {
    "folke/noice.nvim",
    opts = {
      presets = {
        lsp_doc_border = true,
      },
    },
  },
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        sources = {
          explorer = {
            hidden = true,
            ignored = true,
          },
        },
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
