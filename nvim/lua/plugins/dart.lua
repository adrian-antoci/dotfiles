return {
  -- Dart LSP
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        dartls = {
          settings = {
            dart = {
              lineLength = 120,
            },
          },
        },
      },
    },
  },
  -- Dart syntax highlighting via treesitter
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = { "dart" },
    },
  },

}
